import 'package:echo/src/scram.dart';
import 'package:echo/src/utils.dart';

import 'package:test/test.dart';

void main() {
  group('scramParseChallenge Method Test', () {
    test('Must return null if challenge is null', () {
      final result = Scram.scramParseChallenge(null);
      expect(result, isNull);
    });

    test('Must return null if challenge is empty', () {
      final result = Scram.scramParseChallenge('');
      expect(result, isNull);
    });

    test('Must return null if challenge has unknown attribute', () {
      const challenge = 'unknown=value';
      final result = Scram.scramParseChallenge(challenge);
      expect(result, isNull);
    });

    test('Must return the challenge correctly', () {
      const challenge =
          'r=fyko+d2lbbFgONRv9qkxdawL,s=W22ZaJ0SNY7soEsUEjb6,i=4096';
      final result = Scram.scramParseChallenge(challenge);

      expect(result!['nonce'], equals('fyko+d2lbbFgONRv9qkxdawL'));
      expect(
        result['salt'],
        equals(Utils.base64ToArrayBuffer('W22ZaJ0SNY7soEsUEjb6')),
      );
      expect(result['iter'], equals(4096));
    });
  });
}
