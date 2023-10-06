import 'dart:convert';

import 'package:echox/src/echotils/src/idna.dart';
import 'package:test/test.dart';

void main() {
  group('string preparation IDNA test cases', () {
    test('Case folding ASCII U+0043 U+0041 U+0046 U+0045', () {
      const original = 'CAFE';
      const expected = 'cafe';

      final nameprop = IDNA.nameprep(original);
      expect(nameprop, equals(expected));
    });
    test('Case folding 8bit U+00DF (german sharp s)', () {
      const original = '\xC3\x9F';
      const expected = 'ss';
      final decoded = utf8.decode(original.codeUnits);

      final nameprop = IDNA.nameprep(decoded);
      expect(nameprop, equals(expected));
    });
    test('Case folding U+0130 (turkish capital I with dot)', () {
      const original = '\xC4\xB0';
      const expected = 'i\xcc\x87';
      final decoded = utf8.decode(original.codeUnits);

      final nameprop = IDNA.nameprep(decoded);
      expect(nameprop, equals(expected));
    });
    test('Self-reverting case folding U+01F0 and normalization', () {
      const original = '\xC7\xF0';
      const expected = '\xC7\xB0';

      final nameprop = IDNA.nameprep(original);
      expect(nameprop, equals(expected));
    });
  });
}
