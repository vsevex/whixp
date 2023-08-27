import 'package:echotils/echotils.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('xmlElement method tests', () {
    test('must return correct text with valid inputs', () {
      final xmlNode = Echotils.xmlElement('hert');
      expect(xmlNode.toString(), '<hert/>');

      final xmlNodeWithAttr =
          Echotils.xmlElement('hert', attributes: {'attr': 'blya'});
      expect(xmlNodeWithAttr.toString(), '<hert attr="blya"/>');

      final xmlNodeWithMapAttr = Echotils.xmlElement(
        'test',
        attributes: {'attr1': 'blya'},
        text: 'hert, blya!',
      );
      expect(
        xmlNodeWithMapAttr.toString(),
        '<test attr1="blya">hert, blya!</test>',
      );
    });

    test('must return null with invalid inputs', () {
      final xmlNode = Echotils.xmlElement('');
      expect(xmlNode, null);

      final xmlNodeWithAttr =
          Echotils.xmlElement('test', attributes: 'invalid');
      expect(xmlNodeWithAttr, null);
    });
  });

  group('xmlTextNode method tests', () {
    test('must return a text node with the given text', () {
      final node = Echotils.xmlTextNode('hert');
      expect(node.nodeType, equals(xml.XmlNodeType.TEXT));
      expect(node.children.length, equals(0));
      expect(node.root.value, equals('hert'));
    });
  });

  group('isTagEqual method tests', () {
    test('must return true if tags are equal', () {
      final element = xml.XmlElement(xml.XmlName('hert'));
      final result = Echotils.isTagEqual(element, 'hert');
      expect(result, isTrue);
    });
    test('must return false if tags are different', () {
      final element = xml.XmlElement(xml.XmlName('blya'));
      final result = Echotils.isTagEqual(element, 'lerko');
      expect(result, isFalse);
    });
  });

  group('forEachChild method tests', () {
    xml.XmlElement? element;

    setUp(
      () => {
        element = xml.XmlElement(xml.XmlName('test'), [], [
          xml.XmlElement(xml.XmlName('lerko')),
          xml.XmlElement(xml.XmlName('hert')),
          xml.XmlElement(xml.XmlName('blya')),
        ]),
      },
    );
    test('returns 0 without children', () {
      final element = xml.XmlElement(xml.XmlName('test'));
      int count = 0;
      Echotils.forEachChild(element, null, (node) => count++);
      expect(count, 0);
    });
    test('returns exact count of children with passed children', () {
      int count = 0;

      Echotils.forEachChild(element, null, (node) => count++);

      expect(count, 3);
    });

    test('returns exact count with name filter', () {
      int count = 0;
      Echotils.forEachChild(element, 'blya', (node) => count++);
      expect(count, 1);
    });

    test('returns 0 with non-matching name but with children ', () {
      int count = 0;
      Echotils.forEachChild(element, 'firch', (node) => count++);
      expect(count, 0);
    });
  });
}
