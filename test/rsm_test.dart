import 'package:test/test.dart';

import 'package:whixp/src/plugins/plugins.dart';

import 'package:xml/xml.dart' as xml;

import 'test_base.dart';

void main() {
  group('Result Set Management plugin stanza test cases', () {
    test('must properly set max item size', () {
      const rsm = RSMSet(max: 10);
      final fromXML = RSMSet.fromXML(rsm.toXML());

      check(
        rsm,
        fromXML,
        '<set xmlns="http://jabber.org/protocol/rsm"><max>10</max></set>',
      );

      expect(fromXML.max, isNotNaN);
      expect(fromXML.max, equals(10));
      expect(fromXML.after, isNull);
      expect(fromXML.before, isNull);
      expect(fromXML.count, isNull);
    });

    test('must properly set && get first item && index', () {
      const firstItem = 'id';
      const firstIndex = 10;
      const rsm = RSMSet(firstItem: firstItem, firstIndex: firstIndex);
      final fromXML = RSMSet.fromXML(rsm.toXML());

      check(
        rsm,
        fromXML,
        '<set xmlns="http://jabber.org/protocol/rsm"><max>10</max><first index=\'10\'>id</first></set>',
      );

      expect(fromXML.firstItem, isNotNull);
      expect(fromXML.firstItem, equals('id'));
      expect(fromXML.firstIndex, isNotNull);
      expect(fromXML.firstIndex, equals(10));
    });

    test('must properly set before interface', () {
      const rsm = RSMSet(before: '');

      check(
        rsm,
        RSMSet.fromXML(rsm.toXML()),
        '<set xmlns="http://jabber.org/protocol/rsm"><max>0</max><before/></set>',
      );
    });

    test('must return true if there is not any text associated', () {
      const elementString =
          '<set xmlns="http://jabber.org/protocol/rsm"><max>10</max><before/></set>';

      final rsm =
          RSMSet.fromXML(xml.XmlDocument.parse(elementString).rootElement);

      expect(rsm.isBefore, isTrue);
    });

    test('must properly set before interface with value', () {
      const rsm = RSMSet(before: 'value');

      check(
        rsm,
        RSMSet.fromXML(rsm.toXML()),
        '<set xmlns="http://jabber.org/protocol/rsm"><max>0</max><before>value</before></set>',
      );
    });

    test('must return proper text associated', () {
      const elementString =
          '<set xmlns="http://jabber.org/protocol/rsm"><before>value</before></set>';

      final rsm =
          RSMSet.fromXML(xml.XmlDocument.parse(elementString).rootElement);

      expect(rsm.before, equals('value'));
    });
  });
}
