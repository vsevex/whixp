import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import 'package:echo/echo.dart';

import 'package:test/test.dart';

void main() {
  group('hmacIterations Method Test', () {
    test('Must return correct decoded value in the output', () {
      final result = Scram.hmacIteration(
        key: 'password',
        salt: Utils.stringToArrayBuffer('salt'),
        iterations: 4096,
      );
      expect(
        convert.hex.encode(result),
        equals('4b007901b765489abead49d926f721d065a429c1'),
      );
    });
  });

  group('deriveKeys Method Test', () {
    test('Must return correct client key value in the output', () {
      final result = Scram().deriveKeys(
        password: 'pencil',
        salt: Utils.base64ToArrayBuffer('QSXCR+Q6sek8bf92'),
        hashName: 'SHA-1',
        iterations: 4096,
        hashBits: 160,
      );
      expect(
        convert.hex.encode(result['ck']!),
        equals('d53eaaf3c20aeb4e18ecdc0faa9b212967b0be73'),
      );
    });
  });

  group('clientProof Method Test', () {
    test('Must return correct client proof as a result', () {
      const message =
          'n=user,r=fyko+d2lbbFgONRv9qkxdawL,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096,c=biws,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j';
      final result = Scram.clientProof(
        message,
        'SHA-1',
        Uint8List.fromList(
          convert.hex.decode('d53eaaf3c20aeb4e18ecdc0faa9b212967b0be73'),
        ),
      );
      expect(
        convert.hex.encode(result),
        equals('0d33cbbce5519e0225ae0dcc574ce8e6ec5998e9'),
      );
    });
  });

  group('serverSign Method Test', () {
    test('Must return correct server proof as a result', () {
      const message =
          'n=user,r=fyko+d2lbbFgONRv9qkxdawL,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096,c=biws,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j';
      final result = Scram().serverSign(
        message,
        Uint8List.fromList(
          convert.hex.decode('018625aff475ec70628717c5e2b5aa9da2de0a91'),
        ),
        'SHA-1',
      );
      expect(
        convert.hex.encode(result),
        equals('f093bd2aef3dd8c65e49ffca809efdb66b62affa'),
      );
    });
  });

  group('generateCnonce Method Test', () {
    test('Must return true length of the generated value', () {
      final generated = Scram.generateCNonce;
      expect(generated.length, 24);
    });
  });

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
