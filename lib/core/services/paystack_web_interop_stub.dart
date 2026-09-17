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
  // If invoked in stub/non-JS environment, immediately route to in-app fallback
  if (onFallback != null) {
    onFallback();
  } else {
    onClose();
  }
}
