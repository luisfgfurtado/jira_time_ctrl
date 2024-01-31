// Format both dates to 'YYYY-MM-DD'
import 'package:intl/intl.dart';

String formatDate(DateTime dateTime) {
  return "${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
}

bool isToday(DateTime date, [int addDays = 0]) {
  final DateTime today = DateTime.now();
  final DateTime targetDay = date.add(Duration(days: addDays));

  return today.year == targetDay.year && today.month == targetDay.month && today.day == targetDay.day;
}

bool isDateInCurrentWeek(DateTime date) {
  // Get today's date
  DateTime today = DateTime.now();

  // Calculate the first day of the current week
  DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));

  // Calculate the last day of the current week
  DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

  // Remove the time part from dates for comparison
  DateTime normalizedDate = DateTime(date.year, date.month, date.day);
  DateTime normalizedStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  DateTime normalizedEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

  // Check if the given date is between the start and end of the week
  return normalizedDate.isAtLeast(normalizedStart) && normalizedDate.isAtMost(normalizedEnd);
}

extension DateTimeComparison on DateTime {
  bool isAtLeast(DateTime other) => !this.isBefore(other);
  bool isAtMost(DateTime other) => !this.isAfter(other);
}

String getSpentTimeFormatted(int timeSpentSeconds) {
  int hours = timeSpentSeconds ~/ 3600; // Divide by 3600 to get hours
  int minutes = (timeSpentSeconds % 3600) ~/ 60; // Get remainder of hours division, then divide by 60 to get minutes

  String formattedHours = hours.toString().padLeft(2, '0'); // Pad with 0 if hours is a single digit
  String formattedMinutes = minutes.toString().padLeft(2, '0'); // Pad with 0 if minutes is a single digit

  return "$formattedHours:$formattedMinutes";
}

String formatDateTimeToHHMM(DateTime dateTime) {
  return DateFormat('HH:mm').format(dateTime);
}

int getSecondsFromHHmm(String time) {
  List<String> parts = time.split(':');
  if (parts.length != 2) {
    throw FormatException('Invalid time format');
  }

  int hours = int.tryParse(parts[0]) ?? 0;
  int minutes = int.tryParse(parts[1]) ?? 0;

  return (hours * 3600) + (minutes * 60);
}

String formatTimeOfDay(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
