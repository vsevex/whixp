import 'dart:convert';

import 'package:echox/src/idna/idna.dart';

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
      const original = '\xC3\x9F'; // UTF-8 encoding of 'ß'
      const expected = 'ss';

      final nameprop =
          IDNA.nameprep(utf8.decode(original.codeUnits, allowMalformed: true));
      expect(nameprop, equals(expected));
    });
    test('Case folding U+0130 (turkish capital I with dot)', () {
      const original = '\xC4\xB0';
      const expected = 'i\xcc\x87';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Case folding multibyte U+0143 U+037A', () {
      const original = '\xC5\x83\xCD\xBA';
      const expected = '\xC5\x84 \xCE\xB9';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Case folding U+2121 U+33C6 U+1D7BB', () {
      const original = '\xC5\x83\xCD\xBA';
      const expected = '\xC5\x84 \xCE\xB9';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Normalization of U+006a U+030c U+00A0 U+00AA', () {
      const original = '\x6A\xCC\x8C\xC2\xA0\xC2\xAA';
      const expected = '\xC7\xB0 a';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Case folding U+1FB7 and normalization', () {
      const original = '\xE1\xBE\xB7';
      const expected = '\xE1\xBE\xB6\xCE\xB9';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Self-reverting case folding U+0390 and normalization', () {
      const original = '\xCE\x90';
      const expected = '\xCE\x90';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Self-reverting case folding U+03B0 and normalization', () {
      const original = '\xCE\xB0';
      const expected = '\xCE\xB0';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Zero Width Space U+200b', () {
      const original = '\xE2\x80\x8b';
      const expected = '';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
    test('Larger test (expanding)', () {
      const original =
          'X\xC3\x9F\xe3\x8c\x96\xC4\xB0\xE2\x84\xA1\xE2\x92\x9F\xE3\x8c\x80';
      const expected =
          'xss\xe3\x82\xad\xe3\x83\xad\xe3\x83\xa1\xe3\x83\xbc\xe3\x83\x88\xe3\x83\xabi\xcc\x87tel\x28d\x29\xe3\x82\xa2\xe3\x83\x91\xe3\x83\xbc\xe3\x83\x88';

      final nameprop = IDNA.nameprep(utf8.decode(original.codeUnits));
      expect(nameprop, equals(utf8.decode(expected.codeUnits)));
    });
  });
}
