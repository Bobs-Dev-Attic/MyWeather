import 'package:intl/intl.dart';

/// Centralised date/time formatting that respects the 24-hour preference.
class Formatting {
  Formatting(this.use24Hour);

  final bool use24Hour;

  String hour(DateTime t) =>
      DateFormat(use24Hour ? 'HH:00' : 'h a').format(t);

  String time(DateTime t) =>
      DateFormat(use24Hour ? 'HH:mm' : 'h:mm a').format(t);

  String weekday(DateTime d) => DateFormat('EEE').format(d);

  String weekdayLong(DateTime d) => DateFormat('EEEE').format(d);

  String monthDay(DateTime d) => DateFormat('MMM d').format(d);

  String fullDate(DateTime d) => DateFormat('EEE, MMM d').format(d);

  /// "Today" / "Tomorrow" / weekday for daily rows.
  String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return weekdayLong(d);
  }

  static String ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
