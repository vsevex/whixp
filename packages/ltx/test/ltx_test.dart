import 'package:ltx/ltx.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  late LTXParser parser;

  setUp(() {
    parser = LTXParser();
  });

  void emit() => parser.write(
        xml.XmlDocument.parse(
          '<foo><bar>hert</bar></foo>',
        ).rootElement,
      );

  group('parser methods test', () {
    test(
      'notifies start event correctly when fired',
      () {
        parser.on(
          'start',
          (xml.XmlElement element) =>
              expect(element.toXmlString(), equals('<foo/>')),
        );

        emit();
      },
    );

    test(
      'notifies ending xml stanza fired correctly',
      () {
        parser.on(
          'end',
          (xml.XmlElement element) =>
              expect(element.toXmlString(), equals('<foo/>')),
        );

        emit();
      },
    );

    test(
      'notifies when there is a text fired',
      () {
        parser.on(
          'text',
          (xml.XmlElement element) => expect(element.toXmlString(), 'hert'),
        );

        emit();
      },
    );
  });
}
