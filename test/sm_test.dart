import 'package:test/test.dart';

import 'package:whixp/src/plugins/sm/feature.dart';

import 'package:xml/xml.dart' as xml;

void main() {
  group('stream management stanza test cases', () {
    test('answer stanza', () {
      const answer = SMAnswer(h: 1);
      expect(answer.toXMLString(), equals('<a xmlns="urn:xmpp:sm:3" h="1"/>'));
    });

    test('resumed stanza', () {
      const resumedXML =
          '<resumed xmlns="urn:xmpp:sm:3" h="2" previd="some-id"/>';
      final resumed =
          SMResumed.fromXML(xml.XmlDocument.parse(resumedXML).rootElement);

      expect(resumed.toXMLString(), equals(resumedXML));
      expect(resumed.h, equals(2));
      expect(resumed.previd, isNotNull);
      expect(resumed.previd, equals('some-id'));
    });

    test('failed stanza', () {
      const failedXML =
          '<failed xmlns="urn:xmpp:sm:3"><item-not-found>Item not found</item-not-found></failed>';
      final root = xml.XmlDocument.parse(failedXML).rootElement;
      final failed = SMFailed.fromXML(root);

      expect(failed.name, equals('sm:failed'));
      expect(failed.toXMLString(), equals(failedXML));
      expect(failed.cause, isNotNull);
      expect(failed.cause!.content, equals('Item not found'));
      expect(failed.cause!.name, equals('item-not-found'));
    });
  });
}
