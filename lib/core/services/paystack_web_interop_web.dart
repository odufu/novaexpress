// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:js' as js;

void launchPaystackInlineJs({
  required String publicKey,
  required String email,
  required int amountKobo,
  required String reference,
  String? authorizationUrl,
  Map<String, dynamic>? metadata,
  required void Function(String reference) onSuccess,
  required void Function() onClose,
  void Function()? onFallback,
}) {
  try {
    final metaJson = jsonEncode(metadata ?? {});

    // Set globally accessible callback hooks on window
    js.context['__paystack_on_success'] = js.JsFunction.withThis((dynamic _, [dynamic ref]) {
      onSuccess(ref?.toString() ?? reference);
    });

    js.context['__paystack_on_close'] = js.JsFunction.withThis((dynamic _, [dynamic __]) {
      onClose();
    });

    // Execute direct robust JS injection script that manages PaystackPop
    final jsSnippet = '''
      (function() {
        function triggerCheckout() {
          try {
            if (typeof PaystackPop === 'undefined') {
              console.warn('[PAYSTACK_INTEROP] PaystackPop unavailable');
              if (window.__paystack_on_close) window.__paystack_on_close();
              return;
            }

            var handler = PaystackPop.setup({
              key: '$publicKey',
              email: '$email',
              amount: $amountKobo,
              currency: 'NGN',
              ref: '$reference',
              metadata: $metaJson,
              callback: function(response) {
                console.log('[PAYSTACK_INTEROP] Success:', response);
                var resolvedRef = (response && response.reference) ? response.reference : '$reference';
                if (window.__paystack_on_success) {
                  window.__paystack_on_success(resolvedRef);
                }
              },
              onClose: function() {
                console.log('[PAYSTACK_INTEROP] Modal closed by user');
                if (window.__paystack_on_close) {
                  window.__paystack_on_close();
                }
              }
            });

            handler.openIframe();
          } catch(err) {
            console.error('[PAYSTACK_INTEROP] Error opening iframe:', err);
            if (window.__paystack_on_close) window.__paystack_on_close();
          }
        }

        if (typeof PaystackPop === 'undefined') {
          var script = document.createElement('script');
          script.src = 'https://js.paystack.co/v1/inline.js';
          script.async = true;
          script.onload = triggerCheckout;
          script.onerror = function() {
            console.error('[PAYSTACK_INTEROP] CDN load failed');
            if (window.__paystack_on_close) window.__paystack_on_close();
          };
          document.head.appendChild(script);
        } else {
          triggerCheckout();
        }
      })();
    ''';

    js.context.callMethod('eval', [jsSnippet]);
  } catch (e) {
    if (onFallback != null) {
      onFallback();
    } else {
      onClose();
    }
  }
}
