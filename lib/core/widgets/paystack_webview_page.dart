import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../helpers/formatters.dart';
import '../services/paystack_service.dart';

class PaystackWebViewPage extends StatefulWidget {
  final String initialUrl;
  final String reference;
  final double amount;
  final String? title;
  final Function(String reference)? onPaymentSuccess;

  const PaystackWebViewPage({
    super.key,
    required this.initialUrl,
    required this.reference,
    required this.amount,
    this.title = 'Paystack Secure Payment',
    this.onPaymentSuccess,
  });

  @override
  State<PaystackWebViewPage> createState() => _PaystackWebViewPageState();
}

class _PaystackWebViewPageState extends State<PaystackWebViewPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _isChecking = false;
  final PaystackService _paystackService = PaystackService();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _loadingProgress = progress;
                });
              }
            },
            onPageStarted: (String url) {
              _checkCallback(url);
            },
            onPageFinished: (String url) {
              _checkCallback(url);
            },
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url;
              if (_isCallbackUrl(url)) {
                _verifyAndClose(true);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.initialUrl));
    }

    _startBackgroundPolling();
  }

  void _startBackgroundPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final result = await _paystackService.verifyTransaction(widget.reference);
        if (result.isSuccessful && mounted) {
          timer.cancel();
          _verifyAndClose(true);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  bool _isCallbackUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('callback') ||
        lower.contains('standard.paystack.co/close') ||
        lower.contains('trxref=') ||
        lower.contains('reference=') ||
        lower.contains('payment-success');
  }

  void _checkCallback(String url) {
    if (_isCallbackUrl(url)) {
      _verifyAndClose(true);
    }
  }

  Future<void> _verifyAndClose([bool fromSuccessRedirect = false]) async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    try {
      final result = await _paystackService.verifyTransaction(widget.reference);
      if (result.isSuccessful || fromSuccessRedirect) {
        _pollingTimer?.cancel();
        widget.onPaymentSuccess?.call(widget.reference);
        if (mounted) {
          Navigator.pop(context, true);
        }
        return;
      }
    } catch (_) {
      if (fromSuccessRedirect) {
        _pollingTimer?.cancel();
        widget.onPaymentSuccess?.call(widget.reference);
        if (mounted) {
          Navigator.pop(context, true);
        }
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          tooltip: 'Cancel Payment',
          onPressed: () {
            _pollingTimer?.cancel();
            Navigator.pop(context, false);
          },
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF00A2D3)),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.title ?? 'Paystack Checkout',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              CurrencyFormatter.formatNaira(widget.amount),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF00A2D3),
              ),
            ),
          ],
        ),
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.5),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A2D3)),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A2D3)),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Verify Status',
            onPressed: () => _verifyAndClose(false),
          ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_browser_rounded, size: 54, color: Color(0xFF00A2D3)),
                    const SizedBox(height: 16),
                    Text(
                      'Paystack Checkout Opened in Browser',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your payment in the opened Paystack tab. Once done, click the button below to confirm.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _verifyAndClose(true),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('I Have Completed Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
