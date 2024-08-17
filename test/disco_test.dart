import 'package:test/test.dart';

import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/iq.dart';

import 'test_base.dart';

void main() {
  late IQ iq;

  setUp(() => iq = IQ());

  group('disco extension stanza creating and manipulating test cases', () {
    test('disco#info query without node', () {
      iq.payload = DiscoInformation(node: '');

      check(
        iq,
        IQ.fromXML(iq.toXML()),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"/></iq>',
      );
    });

    test('disco#info query with a node', () {
      iq.payload = DiscoInformation(node: 'info');

      check(
        iq,
        IQ.fromXML(iq.toXML()),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info" node="info"/></iq>',
      );
    });

    test('must properly add identity to disco#info', () {
      final info = DiscoInformation();
      info.addIdentity('conference', 'room', type: 'text');
      iq.payload = info;

      check(
        iq,
        IQ.fromXML(iq.toXML()),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="conference" type="text" name="room"/></query></iq>',
      );
    });

    test(
      'must keep first identity when adding multiple copies of the same category and type combination',
      () {
        final info = DiscoInformation();
        info
          ..addIdentity('conference', 'MUC', type: 'text')
          ..addIdentity('conference', 'room', type: 'text');
        iq.payload = info;

        check(
          iq,
          IQ.fromXML(iq.toXML()),
          '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="conference" name="MUC" type="text"/></query></iq>',
        );
      },
    );
  });
}
