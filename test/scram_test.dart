import 'package:convert/convert.dart' as convert;

import 'package:echo/echo.dart';

import 'package:test/test.dart';

void main() {
  group('hmacIteration method test', () {
    test('must return correct decoded value in the output', () {
      final result = Scram.hmacIteration(
        key: 'password',
        salt: 'salt',
        iterations: 4096,
      );
      expect(
        result.codeUnits,
        equals(convert.hex.decode('4b007901b765489abead49d926f721d065a429c1')),
      );
    });
  });

  group('deriveKeys method test', () {
    test('must return correct client key value in the output', () {
      final result = Scram().deriveKeys(
        password: 'pencil',
        salt: 'QSXCR+Q6sek8bf92',
        hashName: 'SHA-1',
        iterations: 4096,
      );
      expect(
        convert.hex.encode(result['sk']!.codeUnits),
        equals('5cdfcf5896307930d4d49260c9f55a532689471e'),
      );
    });
  });

  group('clientProof method test', () {
    test('returns correct client proof as a result', () {
      const message =
          'n=user,r=fyko+d2lbbFgONRv9qkxdawL,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096,c=biws,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j';
      final result = Scram.clientProof(
        message,
        'ÀûQ¨êÇÝKÞÅí',
        'SHA-1',
      );
      expect(
        Echotils.btoa(result),
        equals('frsVRm77a2tPQ5vy+zZuaKRR17o='),
      );
    });
  });

  group('generateCnonce method test', () {
    test('return true length of the generated value', () {
      final generated = Scram.generateCNonce;
      expect(generated.length, 24);
    });
  });

  group('parseChallenge method tests', () {
    test('must return null if challenge is null', () {
      final result = Scram.parseChallenge(null);
      expect(result, isNull);
    });

    test('must return null if challenge is empty', () {
      final result = Scram.parseChallenge('');
      expect(result, isNull);
    });

    test('return null if challenge has unknown attribute', () {
      const challenge = 'unknown=value';
      final result = Scram.parseChallenge(challenge);
      expect(result, isNull);
    });

    test('must return the challenge correctly', () {
      const challenge =
          'r=fyko+d2lbbFgONRv9qkxdawL,s=W22ZaJ0SNY7soEsUEjb6,i=4096';
      final result = Scram.parseChallenge(challenge);

      expect(result!['nonce'], equals('fyko+d2lbbFgONRv9qkxdawL'));
      expect(
        result['salt'],
        equals(Echotils.base64ToArrayBuffer('W22ZaJ0SNY7soEsUEjb6')),
      );
      expect(result['iter'], equals(4096));
    });
  });
}
