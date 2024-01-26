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
