import 'package:echox/src/stream/base.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'class/base.dart';

void main() {
  group('fixing namespace in an XPath expression test cases', () {
    test('must return correct fix of the provided namespace', () {
      final testStanza = XMLBaseTest();
      final testStanzaPlugin = XMLBasePluginTest();

      registerStanzaPlugin(testStanza, testStanzaPlugin);

      testStanza['bar'] = 'attribute!';
      testStanza['baz'] = 'element!';
      testStanza['qux'] = 'overridden';
      testStanza['foobar'] = 'plugin';

      print(testStanza.element!.toXmlString());
    });
  });
}
