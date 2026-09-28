import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatNaira(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}

class DateTimeFormatter {
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  static String formatShortDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = now.year == dateTime.year && now.month == dateTime.month && now.day == dateTime.day;
    final isYesterday = now.subtract(const Duration(days: 1)).year == dateTime.year &&
        now.subtract(const Duration(days: 1)).month == dateTime.month &&
        now.subtract(const Duration(days: 1)).day == dateTime.day;

    final timeStr = DateFormat('hh:mm a').format(dateTime);
    if (isToday) {
      return 'Today, $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return DateFormat('dd MMM, hh:mm a').format(dateTime);
    }
  }
}

class TransactionFeeCalculator {
  /// Calculates dynamic transfer/transaction charge:
  /// ₦100 per ₦5,000 transfer block (e.g. ₦5,000 -> ₦100; ₦5,200 -> ₦200; ₦35,000 -> ₦700).
  static double calculateTransferFee(double amount) {
    if (amount <= 0) return 0.0;
    final blocks = (amount / 5000.0).ceil();
    return (blocks * 100).toDouble();
  }
}

class Formatters {
  static String currency(num amount) {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(amount);
  }
}

class NigerianPhoneHelper {
  /// Normalizes a Nigerian phone number to its canonical 11-digit local format: 080XXXXXXXX.
  /// Handles:
  /// - Country code with +: `+234 801 234 5678` -> `08012345678`
  /// - Country code without +: `2348012345678` -> `08012345678`
  /// - International exit prefix: `002348012345678` -> `08012345678`
  /// - Leading 0 after country code: `+234 (0) 801 234 5678` -> `08012345678`
  /// - Standard local: `08012345678` -> `08012345678`
  /// - Missing leading 0: `8012345678` -> `08012345678`
  /// - Spaces, dashes, parentheses: `080-1234-5678` -> `08012345678`
  static String normalize(String? raw) {
    if (raw == null) return '';
    var clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    if (clean.startsWith('00234')) {
      clean = clean.substring(5);
    } else if (clean.startsWith('234')) {
      clean = clean.substring(3);
    }

    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    if (clean.length >= 10) {
      clean = clean.substring(clean.length - 10);
      return '0$clean';
    }

    return '0$clean';
  }

  /// Returns the core 10 significant digits for deduplication: e.g. `8012345678`
  static String core10Digits(String? raw) {
    final norm = normalize(raw);
    if (norm.length >= 11) {
      return norm.substring(1);
    }
    return norm;
  }

  /// Formats for display: e.g. `0801 234 5678`
  static String formatDisplay(String? raw) {
    final norm = normalize(raw);
    if (norm.length == 11) {
      return '${norm.substring(0, 4)} ${norm.substring(4, 7)} ${norm.substring(7)}';
    }
    return norm;
  }
}

