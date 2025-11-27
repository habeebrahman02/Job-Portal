import 'package:intl/intl.dart';

String formatTime(int seconds) {
  final hrs = (seconds ~/ 3600).toString().padLeft(2, '0');
  final mins = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '$hrs:$mins:$secs';
}

String formatDateTimeShort(DateTime dt) {
  return DateFormat('hh:mm:ss a').format(dt);
}

String formatDateTimeLong(DateTime dt) {
  return DateFormat.yMd().add_jms().format(dt);
}

String formatDurationBetween(DateTime start, DateTime? end) {
  final endTime = end ?? DateTime.now();
  final duration = endTime.difference(start);
  final h = duration.inHours;
  final m = duration.inMinutes % 60;
  return '${h}h ${m}m';
}
