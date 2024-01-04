import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/stream/matcher/xpath.dart';
import 'package:echox/src/transport.dart';

import 'package:test/test.dart';

void main() {
  late Transport transport;

  setUpAll(() {
    transport = testTransport();
  });

  group('using handlers', () {
    test('stream callback handlers must catch upcoming stanza', () async {
      final callback = CallbackHandler(
        'Test',
        (stanza) {
          transport.sendRaw('<message><body>hert</body></message>');
        },
        matcher: XPathMatcher('<test xmlns="tester"/>'),
      );

      transport.registerHandler(callback);

      await receive('<test xmlns="tester"/>', transport);
    });
  });
}
