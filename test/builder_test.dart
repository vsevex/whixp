import 'package:echo/echo.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  EchoBuilder? builder;

  setUp(() {
    /// All tests will go over `iq` stanza builder.
    builder = EchoBuilder.iq(
      attributes: {'to': 'you', 'from': 'me', 'type': 'get', 'id': '1'},
    );
  });

  group('c Method Test', () {
    test('Must return valid tree', () {
      final generation = builder!.c('query').c('example').toString();
      const expected =
          '<iq from="me" id="1" to="you" type="get" xmlns="jabber:client"><query><example/></query></iq>';
      expect(generation, equals(expected));
    });

    test(
      'Must return valid tree when there is child element and attributes',
      () {
        final generation = builder!
            .c('query')
            .c('child', attributes: {'attr': 'value'}).toString();
        const expected =
            '<iq from="me" id="1" to="you" type="get" xmlns="jabber:client"><query><child attr="value"/></query></iq>';
        expect(generation, expected);
      },
    );
  });
}
