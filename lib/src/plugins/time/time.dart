part '_methods.dart';

class DateTimeProfile {
  const DateTimeProfile();
  /// Converts a [String] into a [DateTime] object.
  ///
  /// In the context of ISO 8601 date and time representaiton, the "Z" at the
  /// end indicates that the time is in the UTC (Coordinated Universal Time)
  /// zone. The "Z" stands for "Zulu time", which is another way of saying UTC.
  ///
  /// You can use the returned [DateTime] object to format it without "Z" with
  /// the use of [DateTime.utc] method or [DateTime.toLocal] to convert to
  /// local time or [DateTime.toUtc] to make convertion.
  DateTime parse(String time) => _parse(time);

  /// Returns a formatted [String] version of a date object.
  ///
  /// Default format for a [DateTime] object in XMPP manner is
  /// "YYYY-MM-DDThh:mm:ss[.sss]TZD".
  String format(DateTime time) => _format(time);

  /// Returns a formatted [String] version of a date from the [DateTime] object.
  ///
  /// It should return [String] date in the following format:
  /// "YYYY-MM-DDT00:00:00.000Z"
  String formatDate(DateTime date) => _formatDate(date);

  /// Returns a formatted [String] version of a time from the [DateTime] object.
  ///
  /// If you want to make the formatted string in the Zulu format, you should
  /// make [useZulu] `true.` It default to `false`.
  ///
  /// It should return [String] time in the following format:
  /// "00:00:00".
  String formatTime(DateTime time, {bool useZulu = false}) =>
      _formatTime(time, useZulu: useZulu);

  /// Creates a date only timestamp according to the passed [year], [month],
  /// [day]. The user can choose whether to return [String] or [DateTime]
  /// object through the [asString] boolean.
  dynamic date({int? year, int? month, int? day, bool asString = true}) =>
      _date(year: year, month: month, day: day, asString: asString);
}
