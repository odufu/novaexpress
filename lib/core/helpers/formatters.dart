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

