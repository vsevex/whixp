import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stanza/error.dart';
import 'package:echox/src/stanza/iq.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

import 'test_base.dart';

void main() {
  group('IQ stanza test cases', () {
    test('initializing default IQ values', () {
      final iq = IQ();
      check(iq, '<iq id="0"/>');
    });

    test('setting iq stanza payload must work properly', () {
      final iq = IQ();
      iq.setPayload(
        <xml.XmlElement>[Echotils.xmlElement('test', namespace: 'tester')],
      );
      check(iq, '<iq id="0"><tester xmlns="test"/></iq>');
    });

    test('test behavior for unhandled method', () {
      final iq = IQ();
      final error = StanzaError();
      registerStanzaPlugin(iq, error);

      iq['id'] = 'test';
      (iq['error'] as XMLBase)['condition'] = 'feature-not-implemented';
      (iq['error'] as XMLBase)['text'] = 'No handlers registered';
    });

    test('must properly modify query element of IQ stanzas', () {
      final iq = IQ();

      iq['query'] = 'namespace';
      check(iq, '<iq id="0"><query xmlns="namespace"/></iq>');

      iq['query'] = 'namespace2';
      check(iq, '<iq id="0"><query xmlns="namespace2"/></iq>');

      expect(iq['query'], equals('namespace2'));

      iq.delete('query');
      check(iq, '<iq id="0"/>');
    });

    test('must properly set "result" in reply stanza', () {
      final iq = IQ();
      iq['to'] = 'vsevex@localhost';
      iq['type'] = 'get';
      final newIQ = iq.replyIQ();

      check(newIQ, '<iq id="0" type="result"/>');
    });
  });
}
