import 'package:intl/intl.dart';

/// Date utility extensions
extension DateTimeExtensions on DateTime {
  /// Format as "Mon, Jun 23"
  String get shortDate {
    return DateFormat('EEE, MMM d').format(this);
  }

  /// Format as "June 23, 2026"
  String get longDate {
    return DateFormat('MMMM d, y').format(this);
  }

  /// Format as "8:00 AM"
  String get timeOnly {
    return DateFormat('h:mm a').format(this);
  }

  /// Format as "Jun 23"
  String get monthDay {
    return DateFormat('MMM d').format(this);
  }

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Smart format: "Today", "Yesterday", or "Jun 23"
  String get smartDate {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return monthDay;
  }
}
