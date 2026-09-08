import 'dart:math';

class UuidHelper {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Generates an RFC4122 v4 UUID without external dependencies
  static String generate() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // RFC4122 v4
    values[8] = (values[8] & 0x3f) | 0x80; // RFC4122 variant
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Checks if a string conforms to the standard UUID format
  static bool isUuid(String? str) {
    if (str == null || str.trim().isEmpty) return false;
    return _uuidRegex.hasMatch(str.trim());
  }
}
