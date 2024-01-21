import 'package:test/test.dart';

import 'package:whixp/src/plugins/time/time.dart';

void main() {
  group('XMPP Date and Time Profiles test cases', () {
    test(
      'must properly parse the DateTime object from the given String',
      () {
        const time = '2024-01-21T12:30:00.000Z';
        final parsed = parse(time);

        expect(parsed, equals(DateTime.utc(2024, 1, 21, 12, 30)));
      },
    );

    test(
      'must properly format the passed DateTime object to corresponding String objecdt',
      () {
        final time = DateTime.utc(2024, 8, 1, 01, 30);
        final formatted = format(time);

        expect(formatted, equals('2024-08-01T01:30:00.000Z'));
      },
    );

    test(
      'format only date when passing DateTime object',
      () {
        final time = DateTime(2024, 8, 1, 01, 30);
        final formatted = formatDate(time);

        expect(formatted, equals('2024-08-01T00:00:00.000Z'));
      },
    );

    test(
      'format only time when passing DateTime object',
      () {
        final time = DateTime(2024, 8, 1, 01, 30);
        final formatted = formatTime(time, useZulu: true);

        expect(formatted, equals('01:30:00.000Z'));
      },
    );

    test('must properly create and return DateTime object', () {
      final dateTime = date(year: 2024, month: 8, day: 1, asString: false);

      expect(dateTime, equals(DateTime.utc(2024, 8)));
    });

    test(
      'must properly create and return dateTime in String format',
      () {
        final dateTime = date(year: 2024, month: 8, day: 1);

        expect(dateTime, '2024-08-01T00:00:00.000Z');
      },
    );
  });
}
