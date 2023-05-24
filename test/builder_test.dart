import 'package:echo/echo.dart';

import 'package:test/test.dart';

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

  group('t Method Test', () {
    test('Must return valid string when the text is not empty', () {
      final generated = builder!.t('hello').toString();
      const expected =
          '<iq from="me" id="1" to="you" type="get" xmlns="jabber:client">hello</iq>';
      expect(generated, equals(expected));
    });
  });

  group('up Method Test', () {
    test(
      'Must return valid builder object with a single child element',
      () {
        final builder = EchoBuilder('parent');
        builder.c('child', attributes: {});
        builder.up();
        final result = builder.nodeTree.toString();
        expect(result, equals('<parent><child/></parent>'));
      },
    );

    test(
      'Must return valid tree string with multiple child elements',
      () {
        final builder = EchoBuilder('parent');
        builder.c('child1').up().c('child2', attributes: {});
        final result = builder.nodeTree.toString();
        expect(result, equals('<parent><child1/><child2/></parent>'));
      },
    );

    test(
      'Must return valid node tree string with multiple levels of nesting',
      () {
        final builder = EchoBuilder('parent');
        builder
            .c('child1')
            .c('grandchild1')
            .c('greatgrandchild1')
            .up()
            .up()
            .up()
            .c('child2', attributes: {});
        final result = builder.nodeTree.toString();
        expect(
          result,
          equals(
            '<parent><child1><grandchild1><greatgrandchild1/></grandchild1></child1><child2/></parent>',
          ),
        );
      },
    );
  });
}
