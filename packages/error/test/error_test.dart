import 'package:error/error.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('fromElement factory constructor test', () {
    test('must correctly handle all stream errors by passing XML element', () {
      const applicationElement =
          '''<escape-your-data xmlns="http://example.org/ns" />''';
      const nonza =
          '''
      <stream:error>
        <some-condition xmlns="urn:ietf:params:xml:ns:xmpp-streams" />
        <text xmlns="urn:ietf:params:xml:ns:xmpp-streams" xml:lang="langcode">hert</text>
        $applicationElement
      </stream:error>''';

      final error = Mishap.fromElement(XmlDocument.parse(nonza).rootElement);

      expect(error, isA<Error>());
      expect(error.condition, equals('some-condition'));
      expect(error.text, equals('hert'));
    });

    test('must correctly handle error with whitespaces', () {
      final nonza =
          '''
        <stream:error>
      <some-condition xmlns="urn:ietf:params:xml:ns:xmpp-streams" />
      <text xmlns="urn:ietf:params:xml:ns:xmpp-streams" xml:lang="langcode">
        hert
      </text>
      <escape-your-data xmlns='http://example.org/ns'/>
    </stream:error>
      '''
              .trim();

      final error = Mishap.fromElement(XmlDocument.parse(nonza).rootElement);

      expect(error, isA<Error>());
      expect(error.condition, 'some-condition');
      expect(error.text, '\n        hert\n      ');
    });
  });
}
