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

    js.context['__paystack_on_fallback'] = js.JsFunction.withThis((dynamic _, [dynamic __]) {
      if (onFallback != null) {
        onFallback();
      } else {
        onClose();
      }
    });

    final jsSnippet = '''
      (function() {
        function triggerCheckout() {
          try {
            if (typeof window.payWithPaystack === 'function') {
              window.payWithPaystack({
                key: '$publicKey',
                email: '$email',
                amount: $amountKobo,
                currency: 'NGN',
                ref: '$reference',
                metadata: $metaJson
              }, function(ref) {
                if (window.__paystack_on_success) window.__paystack_on_success(ref);
              }, function() {
                if (window.__paystack_on_close) window.__paystack_on_close();
              });
              return;
            }

            if (typeof PaystackPop === 'undefined') {
              console.warn('[PAYSTACK_INTEROP] PaystackPop unavailable');
              if (window.__paystack_on_fallback) {
                window.__paystack_on_fallback();
              } else if (window.__paystack_on_close) {
                window.__paystack_on_close();
              }
              return;
            }

            // 1. Try V2 newTransaction
            try {
              var paystack = new PaystackPop();
              if (paystack && typeof paystack.newTransaction === 'function') {
                paystack.newTransaction({
                  key: '$publicKey',
                  email: '$email',
                  amount: $amountKobo,
                  currency: 'NGN',
                  ref: '$reference',
                  metadata: $metaJson,
                  onSuccess: function(transaction) {
                    var resolvedRef = (transaction && transaction.reference) ? transaction.reference : '$reference';
                    if (window.__paystack_on_success) window.__paystack_on_success(resolvedRef);
                  },
                  onCancel: function() {
                    if (window.__paystack_on_close) window.__paystack_on_close();
                  },
                  onError: function(err) {
                    console.warn('[PAYSTACK_INTEROP] V2 error:', err);
                    if (window.__paystack_on_fallback) window.__paystack_on_fallback();
                    else if (window.__paystack_on_close) window.__paystack_on_close();
                  }
                });
                return;
              }
            } catch(e) {
              console.warn('[PAYSTACK_INTEROP] V2 attempt failed, trying V1:', e);
            }

            // 2. Fallback to V1 setup
            if (typeof PaystackPop.setup === 'function') {
              var meta = $metaJson;
              var handler = PaystackPop.setup({
                key: '$publicKey',
                email: '$email',
                amount: $amountKobo,
                currency: 'NGN',
                ref: '$reference',
                metadata: meta,
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
              return;
            }

            if (window.__paystack_on_fallback) {
              window.__paystack_on_fallback();
            } else if (window.__paystack_on_close) {
              window.__paystack_on_close();
            }
          } catch(err) {
            console.error('[PAYSTACK_INTEROP] Error opening iframe:', err);
            if (window.__paystack_on_fallback) {
              window.__paystack_on_fallback();
            } else if (window.__paystack_on_close) {
              window.__paystack_on_close();
            }
          }
        }

        if (typeof PaystackPop === 'undefined' && typeof window.payWithPaystack === 'undefined') {
          var script = document.createElement('script');
          script.src = 'https://js.paystack.co/v2/inline.js';
          script.async = true;
          script.onload = triggerCheckout;
          script.onerror = function() {
            console.error('[PAYSTACK_INTEROP] CDN load failed');
            if (window.__paystack_on_fallback) {
              window.__paystack_on_fallback();
            } else if (window.__paystack_on_close) {
              window.__paystack_on_close();
            }
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
