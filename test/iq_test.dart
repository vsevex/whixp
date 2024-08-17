import 'package:test/test.dart';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/disco/info.dart';
import 'package:whixp/src/plugins/disco/items.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

void main() {
  group('IQ stanza test cases', () {
    test('unmarshalling IQs', () {
      const iq = '<iq id="5" type="set" to="vsevex@localhost"/>';
      final stanza = IQ()
        ..type = 'set'
        ..to = JabberID('vsevex@localhost')
        ..id = '5';

      final parsed = IQ.fromString(iq);

      expect(parsed, equals(stanza));
    });

    test('must properly generate IQ stanza', () {
      final iq = IQ()
        ..type = iqTypeResult
        ..from = JabberID('alyosha@localhost')
        ..to = JabberID('vsevex@localhost')
        ..id = '21';

      final payload = DiscoInformation();
      payload.addIdentity('Test Gateway', 'gateway', type: 'mqtt');
      payload.addFeature([
        WhixpUtils.getNamespace('disco_info'),
        WhixpUtils.getNamespace('disco_items'),
      ]);

      iq.payload = payload;

      final xml = iq.toXML();
      final parsedIQ = IQ.fromXML(xml);
      expect(iq.toXMLString(), parsedIQ.toXMLString());
    });

    test('error tag', () {
      final error = ErrorStanza();
      error.code = 503;
      error.type = errorCancel;
      error.reason = 'service-unavailable';
      error.text = 'User session not found';

      final xml = error.toXML();
      final parsed = ErrorStanza.fromXML(xml);
      expect(error, parsed);
    });

    test('disco items case', () {
      final iq = IQ()
        ..type = iqTypeGet
        ..from = JabberID('vsevex@localhost')
        ..to = JabberID('alyosha@localhost')
        ..id = '4';

      final payload = DiscoItems(node: 'music');
      iq.payload = payload;

      final xml = iq.toXMLString();
      expect(
        xml,
        equals(
          '<iq to="alyosha@localhost" from="vsevex@localhost" type="get" id="4"><query xmlns="http://jabber.org/protocol/disco#items" node="music"/></iq>',
        ),
      );

      final parsed = IQ.fromXML(iq.toXML());
      expect(parsed.toXMLString(), iq.toXMLString());
    });

    test('unmarshalling payload', () {
      const String query =
          '<iq to="vsevex@localhost" type="get" id="1"><query xmlns="jabber:iq:version"/></iq>';
      final iq = IQ.fromString(query);
      expect(iq.payload, isNotNull);

      final namespace = (iq.payload! as IQStanza).namespace;
      expect(namespace, 'jabber:iq:version');
      expect(
        iq.payload!.toXMLString(),
        equals('<query xmlns="jabber:iq:version"/>'),
      );
    });
  });
}
