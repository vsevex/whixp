import 'dart:typed_data';

import 'package:echo/src/scram.dart';
import 'package:echo/src/utils.dart';

import 'package:test/test.dart';

void main() {
  group('parseChallenge Method Test', () {
    test('Must return null if challenge is null', () {
      final result = Scram.parseChallenge(null);
      expect(result, isNull);
    });

    test('Must return null if challenge is empty', () {
      final result = Scram.parseChallenge('');
      expect(result, isNull);
    });

    test('Must return null if challenge has unknown attribute', () {
      const challenge = 'unknown=value';
      final result = Scram.parseChallenge(challenge);
      expect(result, isNull);
    });

    test('Must return the challenge correctly', () {
      const challenge =
          'r=fyko+d2lbbFgONRv9qkxdawL,s=W22ZaJ0SNY7soEsUEjb6,i=4096';
      final result = Scram.parseChallenge(challenge);

      expect(result!['nonce'], equals('fyko+d2lbbFgONRv9qkxdawL'));
      expect(
        result['salt'],
        equals(Utils.base64ToArrayBuffer('W22ZaJ0SNY7soEsUEjb6')),
      );
      expect(result['iter'], equals(4096));
    });
  });

  // group('clientProof Method Test', () {
  //   test('Must return expected result', () {
  //     print(
  //       Scram.clientProof(
  //         'n=user,r=123456789,s=abcdefg,c=biws,r=fFj12oE6Zwv/fGHP8waZqGtkzug=',
  //         'SHA-256',
  //         Utils.stringToArrayBuffer('pencil'),
  //       ),
  //     );
  //   });
  // });
}
