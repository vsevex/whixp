part of 'time.dart';

DateTime _parse(String time) => DateTime.parse(time);

String _format(DateTime time) => time.toIso8601String();

String _formatDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).toIso8601String();

String _formatTime(DateTime time, {bool useZulu = false}) {
  time.toUtc();

  final hour = time.hour;
  final minute = time.minute;
  final second = time.second;
  final millisecond = time.millisecond;

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}${useZulu ? '.${millisecond.toString().padLeft(3, '0')}Z' : ''}';
}

dynamic _date({int? year, int? month, int? day, bool asString = true}) {
  final now = DateTime.now();

  year ??= now.year;
  month ??= now.month;
  day ??= now.day;

  final value = DateTime.utc(year, month, day);

  if (asString) {
    return value.toIso8601String();
  }
  return value.toUtc();
}

@visibleForTesting
DateTime parse(String time) => _parse(time);

@visibleForTesting
String format(DateTime time) => _format(time);

@visibleForTesting
String formatDate(DateTime time) => _formatDate(time);

@visibleForTesting
String formatTime(DateTime time, {bool useZulu = false}) =>
    _formatTime(time, useZulu: useZulu);

@visibleForTesting
dynamic date({int? year, int? month, int? day, bool asString = true}) =>
    _date(year: year, month: month, day: day, asString: asString);
