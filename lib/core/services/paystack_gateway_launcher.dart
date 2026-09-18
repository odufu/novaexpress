import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/paystack_constants.dart';
import '../services/paystack_service.dart';
import '../services/paystack_web_interop.dart';
import '../widgets/paystack_checkout_overlay.dart';
import '../widgets/paystack_webview_page.dart';

class PaystackGatewayLauncher {
  static final PaystackService _paystackService = PaystackService();

  /// Opens the real Paystack screen directly on the current screen:
  /// - On Web: Opens the authentic Paystack popup modal (PaystackPop inline iframe) directly over the current screen without opening any new tab.
  /// - On Mobile (Android / iOS): Opens the authentic Paystack in-app WebView screen with close (X) button.
  static Future<void> openPayment({
    required BuildContext context,
    required double amount,
    required String email,
    required String reference,
    required String payerName,
    String? payerCode,
    String? agentId,
    String transactionType = 'remittance',
    String title = 'Paystack Secure Checkout',
    required Function(String reference) onSuccess,
    VoidCallback? onCancel,
  }) async {
    if (!context.mounted) {
      onCancel?.call();
      return;
    }

    bool hasHandledSuccess = false;

    if (kIsWeb) {
      // WEB: Popup the authentic Paystack Checkout modal directly on the current screen without network delay!
      // Paystack Inline JS handles initialization instantly using the public key and pre-cached client SDK.
      launchPaystackInlineJs(
        publicKey: PaystackConstants.publicKey,
        email: email.isNotEmpty ? email : 'customer@novaxpress.ng',
        amountKobo: (amount * 100).round(),
        reference: reference,
        metadata: {
          'payer_name': payerName,
          'payer_code': payerCode ?? 'RDR',
          'transaction_type': transactionType,
          'agent_id': agentId,
        },
        onSuccess: (ref) {
          if (hasHandledSuccess) return;
          hasHandledSuccess = true;
          onSuccess(ref);
        },
        onClose: () async {
          if (hasHandledSuccess) return;
          // Verify on close in case payment completed externally but webhook/callback lagged
          try {
            final result = await _paystackService.verifyTransaction(reference);
            if (result.isSuccessful) {
              if (hasHandledSuccess) return;
              hasHandledSuccess = true;
              onSuccess(reference);
              return;
            }
          } catch (_) {}

          // If not genuinely verified as successful, strictly treat as cancelled
          onCancel?.call();
        },
        onFallback: () {
          if (hasHandledSuccess) return;
          // Fallback if browser extensions or blockers block inline JS
          PaystackCheckoutOverlay.show(
            context: context,
            amount: amount,
            email: email,
            reference: reference,
            payerName: payerName,
            payerCode: payerCode,
            agentId: agentId,
            transactionType: transactionType,
            title: title,
            onSuccess: (ref) {
              if (hasHandledSuccess) return;
              hasHandledSuccess = true;
              onSuccess(ref);
            },
            onCancel: onCancel,
          );
        },
      );
      return;
    }

    // MOBILE (Android / iOS): Open real Paystack in-app screen with native WebView
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00A2D3)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Initializing Real Paystack Gateway...',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    String? authUrl;
    try {
      final res = await _paystackService.initializeTransaction(
        amount: amount,
        email: email.isNotEmpty ? email : 'customer@novaxpress.ng',
        reference: reference,
        metadata: {
          'payer_name': payerName,
          'payer_code': payerCode ?? 'RDR',
          'transaction_type': transactionType,
          'agent_id': agentId,
        },
      );
      authUrl = res['authorization_url']?.toString();
    } catch (e) {
      debugPrint('[PAYSTACK_LAUNCHER] Error initializing Paystack: $e');
    }

    // Safely dismiss the connecting dialog without popping parent routes
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    } else if (context.mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }

    if (!context.mounted) return;

    if (authUrl == null || authUrl.isEmpty) {
      PaystackCheckoutOverlay.show(
        context: context,
        amount: amount,
        email: email,
        reference: reference,
        payerName: payerName,
        payerCode: payerCode,
        agentId: agentId,
        transactionType: transactionType,
        title: title,
        onSuccess: (ref) {
          if (hasHandledSuccess) return;
          hasHandledSuccess = true;
          onSuccess(ref);
        },
        onCancel: onCancel,
      );
      return;
    }

    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => PaystackWebViewPage(
          initialUrl: authUrl!,
          reference: reference,
          amount: amount,
          title: title,
          onPaymentSuccess: (ref) {
            if (hasHandledSuccess) return;
            hasHandledSuccess = true;
            onSuccess(ref);
          },
        ),
      ),
    );

    if (success == true) {
      if (hasHandledSuccess) return;
      hasHandledSuccess = true;
      onSuccess(reference);
    } else {
      try {
        final result = await _paystackService.verifyTransaction(reference);
        if (result.isSuccessful) {
          if (hasHandledSuccess) return;
          hasHandledSuccess = true;
          onSuccess(reference);
          return;
        }
      } catch (_) {}

      onCancel?.call();
    }
  }
}
