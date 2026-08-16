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
}
