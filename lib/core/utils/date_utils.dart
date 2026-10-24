import 'package:intl/intl.dart';

class DateUtils {
  // Get start and end of today
  static DateTime get startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime get endOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  // Get start and end of this week (Monday to Sunday)
  static DateTime get startOfWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static DateTime get endOfWeek {
    final now = DateTime.now();
    final sunday = now.add(Duration(days: 7 - now.weekday));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
  }

  // Get start and end of this month
  static DateTime get startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime get endOfMonth {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDayOfMonth = nextMonth.subtract(const Duration(days: 1));
    return DateTime(lastDayOfMonth.year, lastDayOfMonth.month, lastDayOfMonth.day, 23, 59, 59, 999);
  }

  // Get start and end of last month
  static DateTime get startOfLastMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  static DateTime get endOfLastMonth {
    final now = DateTime.now();
    final firstDayOfThisMonth = DateTime(now.year, now.month, 1);
    final lastDayOfLastMonth = firstDayOfThisMonth.subtract(const Duration(days: 1));
    return DateTime(lastDayOfLastMonth.year, lastDayOfLastMonth.month, lastDayOfLastMonth.day, 23, 59, 59, 999);
  }

  // Check if date is in range
  static bool isDateInRange(DateTime date, DateTime start, DateTime end) {
    return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
        date.isBefore(end.add(const Duration(milliseconds: 1)));
  }

  // Format date for display
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // Relative date formatting
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today, ${formatTime(date)}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, ${formatTime(date)}';
    } else if (now.difference(date).inDays < 7) {
      return '${DateFormat('EEEE').format(date)}, ${formatTime(date)}';
    } else {
      return formatDateTime(date);
    }
  }

  // Get month name
  static String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Get date range for last N months
  static List<DateTime> getLastNMonthsStarts(int n) {
    final now = DateTime.now();
    final months = <DateTime>[];
    
    for (int i = 0; i < n; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      months.add(month);
    }
    
    return months.reversed.toList();
  }

  // Parse date from SMS (handles multiple formats)
  static DateTime? parseSmsDate(String dateStr) {
    try {
      // Try DD-MM-YYYY or DD/MM/YYYY
      final pattern1 = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})');
      final match1 = pattern1.firstMatch(dateStr);
      if (match1 != null) {
        final day = int.parse(match1.group(1)!);
        final month = int.parse(match1.group(2)!);
        final year = int.parse(match1.group(3)!);
        return DateTime(year, month, day);
      }

      // Try DD-MM-YY or DD/MM/YY
      final pattern2 = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{2})');
      final match2 = pattern2.firstMatch(dateStr);
      if (match2 != null) {
        final day = int.parse(match2.group(1)!);
        final month = int.parse(match2.group(2)!);
        final year = 2000 + int.parse(match2.group(3)!);
        return DateTime(year, month, day);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
