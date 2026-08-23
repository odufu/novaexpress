// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void launchPaystackInlineJs({
  required String publicKey,
  required String email,
  required int amountKobo,
  required String reference,
  Map<String, dynamic>? metadata,
  required void Function(String reference) onSuccess,
  required void Function() onClose,
}) {
  try {
    final options = js.JsObject.jsify({
      'key': publicKey,
      'email': email,
      'amount': amountKobo,
      'currency': 'NGN',
      'ref': reference,
      'metadata': metadata ?? {},
    });

    final successCallback = js.JsFunction.withThis((dynamic _, [dynamic ref]) {
      onSuccess(ref?.toString() ?? reference);
    });

    final closeCallback = js.JsFunction.withThis((dynamic _, [dynamic __]) {
      onClose();
    });

    js.context.callMethod('payWithPaystack', [
      options,
      successCallback,
      closeCallback,
    ]);
  } catch (e) {
    // Fallback if JS error
  }
}
