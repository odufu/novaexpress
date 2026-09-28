import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/paystack_constants.dart';
import '../services/paystack_service.dart';
import '../services/paystack_web_interop.dart';
import '../widgets/paystack_webview_page.dart';

class PaystackGatewayLauncher {
  static final PaystackService _paystackService = PaystackService();

  /// Opens the authentic Paystack payment gateway directly:
  /// - On Web: Opens the instant Paystack popup modal (PaystackPop inline iframe) with zero latency.
  /// - On Mobile (Android / iOS): Opens the optimized in-app WebView screen with hardware-accelerated rendering,
  ///   modern Chrome mobile user-agent, and 0-millisecond redirect interception.
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
      // WEB: Popup the authentic Paystack Checkout modal directly on the current screen without network delay.
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
          // Verify on close in case payment completed externally but callback lagged
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
        },
        onFallback: () {
          if (hasHandledSuccess) return;
          // If inline JS is blocked by browser extensions, open the Paystack WebView page
          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (ctx) => PaystackWebViewPage(
                amount: amount,
                email: email,
                reference: reference,
                title: title,
                payerName: payerName,
                payerCode: payerCode,
                agentId: agentId,
                transactionType: transactionType,
                metadata: {
                  'payer_name': payerName,
                  'payer_code': payerCode ?? 'RDR',
                  'transaction_type': transactionType,
                  'agent_id': agentId,
                },
                onPaymentSuccess: (ref) {
                  if (hasHandledSuccess) return;
                  hasHandledSuccess = true;
                  onSuccess(ref);
                },
                onCancel: onCancel,
              ),
            ),
          );
        },
      );
      return;
    }

    // MOBILE (Android / iOS): Open the authentic Paystack in-app screen with native WebView immediately!
    // Zero blocking wait dialog: the screen opens with 0ms perceived latency and loads the gateway in parallel.
    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => PaystackWebViewPage(
          amount: amount,
          email: email.isNotEmpty ? email : 'customer@novaxpress.ng',
          reference: reference,
          title: title,
          payerName: payerName,
          payerCode: payerCode,
          agentId: agentId,
          transactionType: transactionType,
          metadata: {
            'payer_name': payerName,
            'payer_code': payerCode ?? 'RDR',
            'transaction_type': transactionType,
            'agent_id': agentId,
          },
          onPaymentSuccess: (ref) {
            if (hasHandledSuccess) return;
            hasHandledSuccess = true;
            onSuccess(ref);
          },
          onCancel: onCancel,
        ),
      ),
    );

    if (success == true) {
      if (hasHandledSuccess) return;
      hasHandledSuccess = true;
      onSuccess(reference);
    } else {
      // Final sanity verification check in case customer paid via USSD/transfer on another device
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
