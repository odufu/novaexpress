import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/paystack_constants.dart';
import '../helpers/formatters.dart';
import '../services/paystack_service.dart';
import '../services/paystack_web_interop.dart';

/// Ultra-fast, production-grade Paystack hosted checkout view.
/// Operates natively on Android and iOS using optimized WebView settings,
/// and provides seamless fallbacks for Flutter Web.
class PaystackWebViewPage extends StatefulWidget {
  final String? initialUrl;
  final String reference;
  final double amount;
  final String? email;
  final String? title;
  final String? payerName;
  final String? payerCode;
  final String? agentId;
  final String? transactionType;
  final Map<String, dynamic>? metadata;
  final Function(String reference)? onPaymentSuccess;
  final VoidCallback? onCancel;

  const PaystackWebViewPage({
    super.key,
    this.initialUrl,
    required this.reference,
    required this.amount,
    this.email,
    this.title = 'Paystack Secure Payment',
    this.payerName,
    this.payerCode,
    this.agentId,
    this.transactionType = 'order_payment',
    this.metadata,
    this.onPaymentSuccess,
    this.onCancel,
  });

  @override
  State<PaystackWebViewPage> createState() => _PaystackWebViewPageState();
}

class _PaystackWebViewPageState extends State<PaystackWebViewPage> {
  WebViewController? _controller;
  int _loadingProgress = 0;
  bool _isChecking = false;
  bool _hasClosed = false;
  bool _isInitializingSession = false;
  String? _resolvedUrl;
  String? _errorMessage;
  final PaystackService _paystackService = PaystackService();
  Timer? _pollingTimer;
  DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    if (!kIsWeb) {
      _initWebViewController();
    }

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _resolvedUrl = widget.initialUrl;
      if (!kIsWeb && _controller != null) {
        _controller!.loadRequest(Uri.parse(_resolvedUrl!));
      }
      _startBackgroundPolling();
    } else {
      _initializePaystackGateway();
    }
  }

  void _initWebViewController() {
    if (WebViewPlatform.instance == null) {
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 NovaXpress/1.0',
      )
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
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
            _checkCallback(url);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) {
              _checkCallback(url);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (_isCallbackUrl(url)) {
              _handleSuccessCallback(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[PAYSTACK_WEBVIEW] Error (${error.errorCode}): ${error.description}');
            if (mounted && _loadingProgress < 20) {
              setState(() {
                _errorMessage = 'Network connection issue while loading Paystack (${error.description}). Please tap retry.';
              });
            }
          },
        ),
      );

    _controller = controller;
  }

  Future<void> _initializePaystackGateway() async {
    setState(() {
      _isInitializingSession = true;
      _errorMessage = null;
    });

    try {
      final effectiveEmail = (widget.email != null && widget.email!.isNotEmpty)
          ? widget.email!
          : 'customer@novaxpress.ng';

      final meta = Map<String, dynamic>.from(widget.metadata ?? {});
      if (widget.payerName != null) meta['payer_name'] = widget.payerName;
      if (widget.payerCode != null) meta['payer_code'] = widget.payerCode;
      if (widget.agentId != null) meta['agent_id'] = widget.agentId;
      if (widget.transactionType != null) meta['transaction_type'] = widget.transactionType;

      final res = await _paystackService.initializeTransaction(
        amount: widget.amount,
        email: effectiveEmail,
        reference: widget.reference,
        metadata: meta,
        callbackUrl: 'https://standard.paystack.co/close',
      );

      final authUrl = res['authorization_url']?.toString();

      if (!mounted) return;

      if (authUrl != null && authUrl.isNotEmpty) {
        setState(() {
          _resolvedUrl = authUrl;
          _isInitializingSession = false;
        });

        if (!kIsWeb && _controller != null) {
          _controller!.loadRequest(Uri.parse(authUrl));
        }

        _startBackgroundPolling();
      } else {
        setState(() {
          _isInitializingSession = false;
          _errorMessage = 'Could not generate Paystack checkout session. Please check network connection.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingSession = false;
          _errorMessage = 'Network error contacting Paystack: $e';
        });
      }
    }
  }

  void _startBackgroundPolling() {
    _pollingTimer?.cancel();
    // Start polling after 8s grace period to dedicate 100% network bandwidth to initial page render
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _hasClosed) {
        timer.cancel();
        return;
      }

      // Do not poll during the first 6 seconds
      if (DateTime.now().difference(_startTime).inSeconds < 6) return;

      try {
        final result = await _paystackService.verifyTransaction(widget.reference);
        if (result.isSuccessful && mounted && !_hasClosed) {
          timer.cancel();
          _handleSuccessCallback(null);
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
    return lower.contains('standard.paystack.co/close') ||
        lower.contains('paystack.co/close') ||
        lower.contains('trxref=') ||
        lower.contains('reference=') ||
        lower.contains('payment-success') ||
        lower.contains('paystack-webhook');
  }

  void _checkCallback(String url) {
    if (_isCallbackUrl(url)) {
      _handleSuccessCallback(url);
    }
  }

  void _handleSuccessCallback(String? url) {
    if (_hasClosed) return;
    _hasClosed = true;
    _pollingTimer?.cancel();

    String resolvedRef = widget.reference;
    if (url != null) {
      try {
        final uri = Uri.parse(url);
        final refFromQuery = uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
        if (refFromQuery != null && refFromQuery.isNotEmpty) {
          resolvedRef = refFromQuery;
        }
      } catch (_) {}
    }

    widget.onPaymentSuccess?.call(resolvedRef);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _manualVerifyAndClose() async {
    if (_isChecking || _hasClosed) return;
    setState(() => _isChecking = true);

    try {
      final result = await _paystackService.verifyTransaction(widget.reference);
      if (result.isSuccessful) {
        _handleSuccessCallback(null);
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0F172A),
              content: Text(
                'Payment not yet confirmed by Paystack (${result.status.toUpperCase()}). Please complete payment in the interface.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Could not verify with Paystack: $e', style: GoogleFonts.inter(fontSize: 12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Text(
              'Cancel Payment?',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to exit the Paystack checkout? Any pending transaction on this screen will be abandoned.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Continue Payment', style: GoogleFonts.inter(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _pollingTimer?.cancel();
              _hasClosed = true;
              widget.onCancel?.call();
              Navigator.of(context).pop(false);
            },
            child: Text('Exit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          elevation: 1,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Cancel Payment',
            onPressed: _confirmCancel,
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
                    widget.title ?? 'Paystack Secure Checkout',
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
          bottom: (_loadingProgress < 100 && !_hasClosed)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2.5),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
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
              tooltip: 'Check Payment Status',
              onPressed: _manualVerifyAndClose,
            ),
          ],
        ),
        body: _buildBody(context, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 14),
              Text(
                'Connection Error',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
                    _controller?.loadRequest(Uri.parse(widget.initialUrl!));
                    setState(() => _errorMessage = null);
                  } else {
                    _initializePaystackGateway();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2D3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializingSession) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00A2D3).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, size: 40, color: Color(0xFF00A2D3)),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00A2D3)),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to Paystack Secure Gateway...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Encrypting payment session for ${CurrencyFormatter.formatNaira(widget.amount)}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2D3).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 44, color: Color(0xFF00A2D3)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Official Paystack Payment Gateway',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Click below to open Paystack interactive checkout modal for instant Card, Transfer, USSD or QR settlement.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openWebPaystackInline,
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Launch Paystack Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2D3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _manualVerifyAndClose,
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
                    label: Text(
                      'I Have Completed Payment',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00A2D3)));
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_loadingProgress < 60)
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00A2D3)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Official Paystack Interface...',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openWebPaystackInline() {
    launchPaystackInlineJs(
      publicKey: PaystackConstants.publicKey,
      email: widget.email ?? 'customer@novaxpress.ng',
      amountKobo: (widget.amount * 100).round(),
      reference: widget.reference,
      metadata: widget.metadata,
      onSuccess: (ref) {
        _handleSuccessCallback(null);
      },
      onClose: () {
        _manualVerifyAndClose();
      },
    );
  }
}
