import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _indianFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _indianFormatNoSymbol = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  // Format amount with rupee symbol: ₹1,234.56
  static String format(double amount) {
    return _indianFormat.format(amount);
  }

  // Format amount without symbol: 1,234.56
  static String formatWithoutSymbol(double amount) {
    return _indianFormatNoSymbol.format(amount).trim();
  }

  // Format in compact form: ₹1.2k, ₹1.5L, ₹1.2Cr
  static String formatCompact(dynamic amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return _indianFormat.format(amount);
    }
  }

  // Format with sign prefix for income/expense
  static String formatWithSign(double amount, bool isCredit) {
    final formatted = format(amount.abs());
    return isCredit ? '+$formatted' : '-$formatted';
  }

  // Parse currency string to double
  static double? parse(String amountStr) {
    try {
      // Remove currency symbols and commas
      final cleanStr = amountStr
          .replaceAll('₹', '')
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll('INR', '')
          .replaceAll(',', '')
          .trim();
      
      return double.parse(cleanStr);
    } catch (e) {
      return null;
    }
  }

  // Format percentage
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }
}
