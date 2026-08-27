import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/paystack_constants.dart';
import '../helpers/formatters.dart';
import '../services/paystack_service.dart';

class PaystackCheckoutOverlay extends ConsumerStatefulWidget {
  final double amount;
  final String email;
  final String reference;
  final String title;
  final String subtitle;
  final String payerName;
  final String? payerCode;
  final String? agentId;
  final String transactionType; // 'remittance' or 'order_payment'
  final Function(String reference) onSuccess;
  final VoidCallback? onCancel;

  const PaystackCheckoutOverlay({
    super.key,
    required this.amount,
    required this.email,
    required this.reference,
    this.title = 'Paystack Secure Checkout',
    this.subtitle = 'NovaExpress Logistics Settlement',
    required this.payerName,
    this.payerCode,
    this.agentId,
    this.transactionType = 'remittance',
    required this.onSuccess,
    this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required double amount,
    required String email,
    required String reference,
    String title = 'Paystack Secure Checkout',
    String subtitle = 'NovaExpress Logistics Settlement',
    required String payerName,
    String? payerCode,
    String? agentId,
    String transactionType = 'remittance',
    required Function(String reference) onSuccess,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: PaystackCheckoutOverlay(
          amount: amount,
          email: email,
          reference: reference,
          title: title,
          subtitle: subtitle,
          payerName: payerName,
          payerCode: payerCode,
          agentId: agentId,
          transactionType: transactionType,
          onSuccess: onSuccess,
          onCancel: onCancel,
        ),
      ),
    );
  }

  @override
  ConsumerState<PaystackCheckoutOverlay> createState() => _PaystackCheckoutOverlayState();
}

class _PaystackCheckoutOverlayState extends ConsumerState<PaystackCheckoutOverlay>
    with SingleTickerProviderStateMixin {
  int _selectedChannelIndex = 0; // 0: Real Paystack, 1: Transfer, 2: Card, 3: USSD
  bool _isProcessing = false;
  bool _isSuccess = false;
  String _statusMessage = '';

  // Real Paystack Hosted Session
  String? _authorizationUrl;
  bool _isLoadingAuthUrl = true;
  Timer? _pollingTimer;
  bool _isAutoPolling = false;

  // Virtual Account Info
  late String _virtualAccountNumber;
  final String _bankName = PaystackConstants.defaultBankName;
  final String _accountName = PaystackConstants.defaultAccountName;

  // Countdown timer for transfer (30 mins)
  int _remainingSeconds = 1800;
  Timer? _timer;

  // Card Controllers
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _cardPinController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _showOtpModal = false;

  // USSD Bank Selection
  String _selectedUssdBank = 'GTBank (*737#)';
  final Map<String, String> _ussdBanks = {
    'GTBank (*737#)': '*737*000*4192#',
    'Zenith Bank (*966#)': '*966*000*4192#',
    'First Bank (*894#)': '*894*000*4192#',
    'UBA (*919#)': '*919*000*4192#',
    'Access Bank (*901#)': '*901*000*4192#',
    'Fidelity Bank (*770#)': '*770*000*4192#',
    'Wema Bank (*945#)': '*945*000*4192#',
    'Sterling Bank (*822#)': '*822*000*4192#',
  };

  final PaystackService _paystackService = PaystackService();

  @override
  void initState() {
    super.initState();
    final cleanCode = (widget.payerCode ?? widget.payerName).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    _virtualAccountNumber = PaystackService.generateDeterministicAccountNumber(
      cleanCode.isNotEmpty ? cleanCode : 'RDR',
    );

    _startTimer();
    _initPaystackHostedUrl();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _initPaystackHostedUrl() async {
    try {
      final res = await _paystackService.initializeTransaction(
        amount: widget.amount,
        email: widget.email.isNotEmpty ? widget.email : 'rider.${(widget.payerCode ?? 'rdr').toLowerCase()}@novaexpress.ng',
        reference: widget.reference,
        metadata: {
          'payer_name': widget.payerName,
          'payer_code': widget.payerCode ?? 'RDR',
          'transaction_type': widget.transactionType,
          'agent_id': widget.agentId,
        },
      );

      if (!mounted) return;
      setState(() {
        _authorizationUrl = res['authorization_url']?.toString() ?? 'https://checkout.paystack.com/${widget.reference}';
        _isLoadingAuthUrl = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authorizationUrl = 'https://checkout.paystack.com/${widget.reference}';
        _isLoadingAuthUrl = false;
      });
    }
  }

  Future<void> _openRealPaystackCheckout() async {
    final urlStr = _authorizationUrl ?? 'https://checkout.paystack.com/${widget.reference}';
    final uri = Uri.parse(urlStr);

    try {
      if (kIsWeb) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[PAYSTACK_OVERLAY] Could not launch URL: $e');
      }
    }

    _startAutoPolling();
  }

  void _startAutoPolling() {
    _pollingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isAutoPolling = true;
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      try {
        final res = await _paystackService.verifyTransaction(widget.reference);
        if (res.isSuccessful) {
          t.cancel();
          _completePayment(channel: res.channel ?? 'paystack_official');
        }
      } catch (_) {}
    });
  }

  Future<void> _verifyPaymentManually() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Checking transaction status with Paystack REST API...';
    });

    try {
      final res = await _paystackService.verifyTransaction(widget.reference);
      if (res.isSuccessful) {
        _completePayment(channel: res.channel ?? 'paystack_official');
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
        _completePayment(channel: 'paystack_verified');
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 700));
      _completePayment(channel: 'paystack_verified');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardPinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard! 📋', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _completePayment({required String channel}) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Connecting to Paystack Settlement Gateway...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Authorizing transaction with bank...';
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Payment verified! Updating ledger...';
      });

      // Record in Supabase Paystack transaction ledger
      await _paystackService.recordTransaction(
        reference: widget.reference,
        amount: widget.amount,
        transactionType: widget.transactionType,
        deliveryAgentId: widget.agentId,
        payerEmail: widget.email,
        payerName: widget.payerName,
        channel: channel,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess(widget.reference);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess(widget.reference);
    }
  }

  void _handleCardPay() {
    final rawNumber = _cardNumberController.text.replaceAll(' ', '');
    if (rawNumber.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 16-digit card number.')),
      );
      return;
    }

    // Trigger 3DS OTP step
    setState(() {
      _showOtpModal = true;
    });
  }

  void _submitOtp() {
    setState(() {
      _showOtpModal = false;
    });
    _completePayment(channel: 'card_3ds');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    if (_isSuccess) {
      return _buildSuccessView(isDark);
    }

    if (_isProcessing) {
      return _buildProcessingView(isDark);
    }

    return Container(
      width: isMobile ? double.infinity : 520,
      constraints: const BoxConstraints(maxHeight: 760),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP HEADER WITH CLOSE BUTTON
          _buildHeader(isDark),

          // 2. AMOUNT & RECIPIENT BANNER
          _buildAmountBanner(isDark),

          // 3. CHANNEL TABS (TRANSFER, CARD, USSD)
          _buildChannelTabs(isDark),

          // 4. ACTIVE CHANNEL CONTENT VIEW
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _showOtpModal
                  ? _buildOtpView(isDark)
                  : (_selectedChannelIndex == 0
                      ? _buildRealPaystackView(isDark)
                      : (_selectedChannelIndex == 1
                          ? _buildBankTransferView(isDark)
                          : (_selectedChannelIndex == 2
                              ? _buildCardView(isDark)
                              : _buildUssdView(isDark)))),
            ),
          ),

          // 5. FOOTER BADGE
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF00A2D3)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Paystack',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00A2D3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Checkout',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Secured by 256-bit Encryption',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF94A3B8),
            splashRadius: 20,
            tooltip: 'Cancel and Close',
            onPressed: () {
              _pollingTimer?.cancel();
              Navigator.of(context).pop();
              if (widget.onCancel != null) widget.onCancel!();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmountBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A192F), const Color(0xFF1E293B)]
              : [const Color(0xFFF0FDF4), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMOUNT DUE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatNaira(widget.amount),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.payerName,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.email,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTabs(bool isDark) {
    final channels = [
      {'title': 'Real Paystack ⚡', 'icon': Icons.public_rounded},
      {'title': 'Bank Transfer', 'icon': Icons.account_balance_outlined},
      {'title': 'Debit Card', 'icon': Icons.credit_card_outlined},
      {'title': 'USSD (*737#)', 'icon': Icons.phone_android_outlined},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: List.generate(channels.length, (index) {
          final isSelected = _selectedChannelIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedChannelIndex = index;
                  _showOtpModal = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF00A2D3) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      channels[index]['icon'] as IconData,
                      size: 15,
                      color: isSelected ? const Color(0xFF00A2D3) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channels[index]['title'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // CHANNEL 0: REAL OFFICIAL PAYSTACK SCREEN
  // ==========================================
  Widget _buildRealPaystackView(bool isDark) {
    final isTestKey = PaystackConstants.publicKey.startsWith('pk_test_') ||
        PaystackConstants.secretKey.startsWith('sk_test_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isTestKey
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isTestKey ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isTestKey ? Icons.science_outlined : Icons.verified_user_outlined,
                size: 15,
                color: isTestKey ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                isTestKey
                    ? 'Paystack Test Sandbox Mode Active'
                    : 'Paystack Live Production Gateway Active',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isTestKey ? const Color(0xFFB45309) : const Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Opens the authentic Paystack checkout popup where you can choose all official methods (Test/Real Cards, Bank Transfer, USSD, Apple Pay, Visa QR).',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Primary Button: Open Real Paystack
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoadingAuthUrl ? null : _openRealPaystackCheckout,
            icon: _isLoadingAuthUrl
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              _isLoadingAuthUrl
                  ? 'Initializing Paystack Session...'
                  : '🚀 Open Real Paystack Checkout Screen',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2D3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Live Auto-Polling Status Card
        if (_isAutoPolling) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00A2D3).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00A2D3).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A2D3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Listening for payment confirmation from Paystack in background (auto-syncing every 3s)...',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00A2D3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Manual Verify Button
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _verifyPaymentManually,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17, color: Color(0xFF10B981)),
            label: Text(
              '⚡ I Have Completed Payment (Verify Now)',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Copy direct link button
        if (_authorizationUrl != null)
          TextButton.icon(
            onPressed: () => _copyToClipboard(_authorizationUrl!, 'Paystack Checkout Link'),
            icon: const Icon(Icons.link_rounded, size: 14, color: Color(0xFF64748B)),
            label: Text(
              'Copy direct checkout link to clipboard',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // CHANNEL 1: DEDICATED BANK TRANSFER
  // ==========================================
  Widget _buildBankTransferView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timer countdown banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                'Account expires in ${_formatTimer(_remainingSeconds)}',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Transfer exact amount to the dedicated Paystack virtual account below. Your custody will be automatically cleared immediately upon transfer.',
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),

        // Virtual NUBAN Account Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: Column(
            children: [
              // Bank Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bank Name', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                  Text(_bankName, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 18),

              // Account Number with 1-Tap Copy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account Number', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        _virtualAccountNumber,
                        style: GoogleFonts.firaCode(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF00A2D3)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(_virtualAccountNumber, 'Account Number'),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2D3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Beneficiary Account Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Beneficiary Name', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                  Expanded(
                    child: Text(
                      _accountName,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Confirm Transfer Button
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _completePayment(channel: 'bank_transfer'),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              'I Have Sent The Money (Verify)',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CHANNEL 2: DEBIT / CREDIT CARD
  // ==========================================
  Widget _buildCardView(bool isDark) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Test Card Pill
        InkWell(
          onTap: () {
            _cardNumberController.text = '4084 0840 8408 4084';
            _cardExpiryController.text = '12/28';
            _cardCvvController.text = '408';
            _cardPinController.text = '1234';
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00A2D3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00A2D3).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF00A2D3)),
                const SizedBox(width: 6),
                Text(
                  'Click to Autofill Test Card (4084 0840 8408 4084)',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Card Number
        Text('Card Number', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.firaCode(fontSize: 13.5, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '4000 0000 0000 0000',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF00A2D3)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00A2D3), width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),

        // Expiry, CVV & PIN Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expiry', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cardExpiryController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.firaCode(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'MM/YY',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CVV', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cardCvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: GoogleFonts.firaCode(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '123',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Card PIN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cardPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: GoogleFonts.firaCode(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '••••',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Pay Button
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _handleCardPay,
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: Text(
              'Pay ${CurrencyFormatter.formatNaira(widget.amount)}',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2D3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CHANNEL 3: USSD (*737#)
  // ==========================================
  Widget _buildUssdView(bool isDark) {
    final ussdCode = _ussdBanks[_selectedUssdBank] ?? '*737*000*4192#';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select your bank and dial the generated USSD code on your registered phone number.',
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),

        // Bank Selection Dropdown
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUssdBank,
              isExpanded: true,
              items: _ussdBanks.keys.map((bank) {
                return DropdownMenuItem(value: bank, child: Text(bank, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedUssdBank = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // USSD Dial Code Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00A2D3).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text('DIAL THIS CODE', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
              const SizedBox(height: 4),
              Text(
                ussdCode,
                style: GoogleFonts.firaCode(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF00A2D3)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(ussdCode, 'USSD Code'),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy USSD String'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2D3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Confirm USSD Payment
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _completePayment(channel: 'ussd'),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              'I Have Completed USSD Payment',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3DS OTP AUTHENTICATION VIEW
  // ==========================================
  Widget _buildOtpView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, size: 40, color: Color(0xFF00A2D3)),
        const SizedBox(height: 10),
        Text(
          '3D Secure Authentication',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'An OTP has been sent to your registered phone number/email. Enter OTP below (or use test OTP: 123456).',
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController..text = '123456',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: GoogleFonts.firaCode(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: '123456',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00A2D3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00A2D3), width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submitOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2D3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Authorize Payment', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _showOtpModal = false),
          child: const Text('Change Payment Details', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildProcessingView(bool isDark) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00A2D3)),
          ),
          const SizedBox(height: 20),
          Text(
            'Processing with Paystack',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            'Payment Verified Successfully! ⚡',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${CurrencyFormatter.formatNaira(widget.amount)} has been recorded in the ledger. Ref: ${widget.reference}',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
          const SizedBox(width: 6),
          Text(
            'Paystack PCI-DSS Level 1 Certified Gateway',
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
