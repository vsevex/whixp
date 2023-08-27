import 'package:escaper/escaper.dart';

import 'package:test/test.dart';

void main() {
  group('escape and unescape methods test', () {
    test('must replace space with corresponding escaper', () {
      const testNode = 'hert blya';
      expect(Escaper().escape(testNode), equals('hert\\20blya'));
    });

    test(
      'must replace space and backslash with corresponding escapers',
      () {
        const testNode = 'Example / escaper';
        expect(
          Escaper().escape(testNode),
          equals('Example\\20\\2f\\20escaper'),
        );
      },
    );

    test('must unescape from the escaped text', () {
      const testNode = 'hert\\20blat';
      expect(Escaper().unescape(testNode), equals('hert blat'));
    });
  });

  group('xmlEscape method test', () {
    test(
      'must replace quotation marks in the parsed xml text symbols with the corresponding escaper',
      () {
        const testText = 'hert "blya"';
        expect(Escaper().xmlEscape(testText), equals('hert &quot;blya&quot;'));
      },
    );

    test(
      'must replace chars from the parsed xml text with the corresponding escapers',
      () {
        const testText = 'hert & <blya>';
        expect(
          Escaper().xmlEscape(testText),
          equals('hert &amp; &lt;blya&gt;'),
        );
      },
    );
  });
}
