import 'package:test/test.dart';

import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/stanza/iq.dart';

void main() {
  group('bind stanza test cases', () {
    test('must generate iq stanza correctly from string', () {
      const stanza =
          '<iq type="set" id="bind"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><resource>resource</resource></bind></iq>';
      final iq = IQ.fromString(stanza);

      expect(iq.payload, isNotNull);
      expect(iq.payload, isA<Bind>());
      final payload = iq.payload! as Bind;
      expect(payload.resource, equals('resource'));
    });

    test(
      'must build bind stanza correctly depending on the given params',
      () {
        const bind = Bind(resource: 'resource', jid: 'vsevex@localhost');

        expect(
          bind.toXMLString(),
          equals(
            '<bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><resource>resource</resource><jid>vsevex@localhost</jid></bind>',
          ),
        );
      },
    );
  });
}
