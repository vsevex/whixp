import 'package:test/test.dart';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/message.dart';

void main() {
  group('message stanza test cases', () {
    test('generate message stanza', () {
      final message = Message(body: 'salam', subject: 'greeting')
        ..type = messageTypeChat
        ..to = JabberID('vsevex@localhost')
        ..from = JabberID('alyosha@localhost')
        ..id = '5';

      final xml = message.toXML();
      final parsed = Message.fromXML(xml);
      expect(parsed.toXMLString(), message.toXMLString());
      expect(parsed.subject, isNotNull);
      expect(parsed.subject, 'greeting');
      expect(parsed.body, isNotNull);
      expect(parsed.body, 'salam');
      expect(parsed.type, isNotNull);
      expect(parsed.type, 'chat');
    });

    test(
      'must decode message when there is error in message stanza',
      () {
        const String message =
            '<message to="recipient@example.com" from="sender@example.com" type="error"><error type="cancel"><not-acceptable xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/></error></message>';

        final error = ErrorStanza.fromString(
          '<error type="cancel"><not-acceptable xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/></error>',
        );

        final parsed = Message.fromString(message);
        expect(parsed.error, isNotNull);
        expect(parsed.error, error);
        expect(parsed.error!.type, isNotNull);
        expect(parsed.error!.type, errorCancel);
      },
    );
  });
}
