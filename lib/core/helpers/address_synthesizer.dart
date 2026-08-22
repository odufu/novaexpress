class AddressSynthesizer {
  /// Cleans raw customer unstructured address input by stripping phone numbers,
  /// delivery instructions, and common noise tokens before geocoding or routing.
  static String cleanAddressText(String rawAddress) {
    if (rawAddress.trim().isEmpty) return '';

    return rawAddress
        // Strip Nigerian phone numbers (e.g. 08031234567, +2348031234567)
        .replaceAll(RegExp(r'\b(0[789][01]\d{8}|\+?234\d{10})\b'), '')
        // Strip conversational arrival instructions
        .replaceAll(
          RegExp(
            r'\b(call|contact|deliver|reach|urgent|please|before|after|near|behind|opposite|beside)\b.*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[,;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Synthesizes a clean search query for geocoding engines or map intents
  static String synthesizeQuery({
    required String address,
    String? city,
    required String state,
    String country = 'Nigeria',
  }) {
    final cleaned = cleanAddressText(address);
    final parts = <String>[];

    if (cleaned.isNotEmpty) {
      parts.add(cleaned);
    }

    if (city != null && city.trim().isNotEmpty && !cleaned.toLowerCase().contains(city.toLowerCase().trim())) {
      parts.add(city.trim());
    }

    if (state.trim().isNotEmpty && !cleaned.toLowerCase().contains(state.toLowerCase().trim())) {
      parts.add(state.trim());
    }

    if (country.trim().isNotEmpty) {
      parts.add(country.trim());
    }

    return parts.where((p) => p.isNotEmpty).join(', ');
  }
}
