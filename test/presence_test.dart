import 'package:test/test.dart';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stanza/presence.dart';

void main() {
  group('presence stanza test cases', () {
    test('must generate presence and attach attributes', () {
      final presence = Presence();

      presence
        ..type = presenceShowChat
        ..from = JabberID('vsevex@localhost')
        ..to = JabberID('alyosha@localhost')
        ..id = 'someID';

      final xml = presence.toXML();
      expect(
        xml.toString(),
        '<presence to="alyosha@localhost" from="vsevex@localhost" type="chat" id="someID"/>',
      );

      final fromString = Presence.fromString(
        '<presence type="chat" id="someID" from="vsevex@localhost" to="alyosha@localhost"/>',
      );
      expect(fromString.to, isNotNull);
      expect(fromString.to, equals(JabberID('alyosha@localhost')));
      expect(fromString.from, isNotNull);
      expect(fromString.from, equals(JabberID('vsevex@localhost')));
      expect(fromString.id, isNotNull);
      expect(fromString.id, equals('someID'));
    });

    test('presence sub elements test case', () {
      final presence = Presence(
        show: presenceShowAway,
        status: 'Sleeping',
        priority: 10,
      );

      presence
        ..type = presenceShowChat
        ..from = JabberID('vsevex@localhost')
        ..to = JabberID('alyosha@localhost')
        ..id = 'someID';

      final xml = presence.toXML();
      final fromXML = Presence.fromXML(xml);

      expect(fromXML.show, isNotNull);
      expect(fromXML.show, equals(presence.show));
      expect(fromXML.status, isNotNull);
      expect(fromXML.status, equals(presence.status));
      expect(fromXML.priority, isNotNull);
      expect(fromXML.priority, equals(presence.priority));
    });

    test('presence with error substanza', () {
      final presence = Presence.fromString(
        '<presence><error code="404" type="cancel"><item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/></error></presence>',
      );
      final fromXML = Presence.fromXML(presence.toXML());

      expect(fromXML.error, isNotNull);
      expect(fromXML.error!.code, 404);
      expect(fromXML.error!.type, errorCancel);
    });
  });
}
