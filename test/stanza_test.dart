import 'package:echox/src/echotils/src/echotils.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('stanza base test cases for methods', () {
    test('must properly set "to" interface of base', () {
      final stanza = StanzaBase();
      stanza['to'] = 'hert@cart.net';
      expect(stanza['to'], equals('hert@cart.net'));
      stanza.setTo('hert@cart1.net');
      expect(stanza['to'], equals('hert@cart1.net'));
    });

    test('must properly set "from" interface of base', () {
      final stanza = StanzaBase();
      stanza['from'] = 'hert@cart.net';
      expect(stanza['from'], equals('hert@cart.net'));
      stanza.setFrom('hert@cart1.net');
      expect(stanza['from'], equals('hert@cart1.net'));
    });

    test('"payload" interface of base various tests', () {
      final stanza = StanzaBase();
      expect(stanza.payload, isEmpty);

      stanza['payload'] = xml.XmlElement(xml.XmlName('cart'));
      expect(stanza.payload.length, equals(1));

      stanza.setPayload([xml.XmlElement(xml.XmlName('cart'))]);
      expect(stanza.payload.length, equals(2));

      stanza.deletePayload();
      expect(stanza.payload, isEmpty);

      stanza['payload'] = xml.XmlElement(xml.XmlName('cart'));
      expect(stanza.payload.length, equals(1));

      stanza.delete('payload');
      expect(stanza.payload, isEmpty);
    });

    test('reply functionality must work properly', () {
      final stanza = StanzaBase();

      stanza.setTo('cart@hert.org');
      stanza.setFrom('lerko@hert.org');
      stanza.setPayload([Echotils.xmlElement('foo', namespace: 'test')]);

      final reply = stanza.reply();

      expect(reply['to'], equals('lerko@hert.org'));
      expect(reply.payload, isEmpty);
    });
  });
}
