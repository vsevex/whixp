import 'dart:typed_data';

import 'package:echox/src/echotils/echotils.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('isTagEqual method tests', () {
    test('must return true if tags are equal', () {
      final element = xml.XmlElement(xml.XmlName('child1'));
      final result = Echotils.isTagEqual(element, 'child1');
      expect(result, isTrue);
    });
    test('must return false if tags are different', () {
      final element = xml.XmlElement(xml.XmlName('tag'));
      final result = Echotils.isTagEqual(element, 'differentOne');
      expect(result, isFalse);
    });
  });

  group('XHTML getText method tests', () {
    test('must return valid text', () {
      final element =
          xml.XmlDocument.parse('<root>hert, blyat</root>').rootElement;
      final result = Echotils.getText(element);
      expect(result, equals('hert, blyat'));
    });

    test('must return valid text', () {
      final element = xml.XmlDocument.parse(
        '<description>blya, <b>hert</b> lerko.</description>',
      ).rootElement;
      final result = Echotils.getText(element);
      expect(result, 'blya, hert lerko.');
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

  group('serialize method tests', () {
    test('returns null if element is null', () {
      final result = Echotils.serialize(null);
      expect(result, isNull);
    });
    test('returns correct serialization', () {
      final result = Echotils.serialize(xml.XmlElement(xml.XmlName('hert')));
      expect(result, '<hert/>');
    });

    test('returns correct serialization with two attributes set', () {
      final element = xml.XmlElement(xml.XmlName('a'));
      element.setAttribute('href', 'https://example.com');
      element.setAttribute('target', '_cart');
      final result = Echotils.serialize(element);
      const expected = '<a href="https://example.com" target="_cart"/>';
      expect(result, expected);
    });

    test('returns valid serialization when there is CDATA section', () {
      final document = xml.XmlDocument.parse(
        '<book><![CDATA[This is some <CDATA> content.]]></book>',
      );
      final result = Echotils.serialize(document.rootElement);
      const expected = '<book><![CDATA[This is some <CDATA> content.]]></book>';
      expect(result, expected);
    });
  });

  group('copyElement method tests', () {
    test(
        'must return correct deep copy if element copies with attributes and children',
        () {
      final element = xml.XmlElement(xml.XmlName('test'));
      element.setAttribute('attr1', 'value1');
      element.setAttribute('attr2', 'value2');
      element.children.add(xml.XmlElement(xml.XmlName('cart')));
      element.children.add(xml.XmlElement(xml.XmlName('lerko')));

      /// Create a copy of the given XML
      final copy = Echotils.copyElement(element);

      expect((copy as xml.XmlElement).name.local, equals('test'));
      expect(copy.attributes.length, equals(2));
      expect(copy.getAttribute('attr2'), equals('value2'));
      expect((copy.children[0] as xml.XmlElement).name.local, equals('cart'));
    });

    test('must return valid copy from provided xmlString', () {
      const xmlString =
          '<book id="123"><title>Notes from Underground</title><author>Fyodor Mikhaylovich</author></book>';
      final document = xml.XmlDocument.parse(xmlString);
      final originalElement = document.getElement('book');
      final copy = Echotils.copyElement(originalElement!);
      const expected =
          '<book id="123"><title>Notes from Underground</title><author>Fyodor Mikhaylovich</author></book>';
      expect(copy.toString(), expected);
    });

    test('returns copied text element type correctly', () {
      final element = xml.XmlText('cart');
      final copy = Echotils.copyElement(element);

      expect(copy.nodeType, equals(xml.XmlNodeType.TEXT));
    });

    test('will throw an error for unsupported node type', () {
      final element = xml.XmlComment('test');
      expect(() => Echotils.copyElement(element), throwsArgumentError);
    });
  });

  group('xmlElement() method tests', () {
    test('must return correct text with valid inputs', () {
      final xmlNode = Echotils.xmlElement('lerko');
      expect(xmlNode.toString(), '<lerko/>');

      final xmlNodeWithAttr =
          Echotils.xmlElement('test', attributes: {'attr1': 'hert'});
      expect(xmlNodeWithAttr.toString(), '<test attr1="hert"/>');

      final xmlNodeWithMapAttr = Echotils.xmlElement(
        'test',
        attributes: {'attr1': 'value1'},
        text: 'Hello, blya!',
      );
      expect(
        xmlNodeWithMapAttr.toString(),
        '<test attr1="value1">Hello, blya!</test>',
      );
    });

    test('returns valid output with element name and attributes', () {
      final element = Echotils.xmlElement(
        'book',
        attributes: {'author': 'Vsevolod', 'year': '2023'},
      );
      expect(
        Echotils.serialize(element),
        '<book author="Vsevolod" year="2023"/>',
      );
    });
  });

  group('base64ToArrayBuffer method tests', () {
    test('must return a valid array buffer', () {
      const input = 'SGVsbG8gV29ybGQ=';
      final output = Echotils.base64ToArrayBuffer(input);
      expect(output, isA<Uint8List>());
    });

    test('must return expected output', () {
      const input = 'YmFzZTY0IGlzIGEgdGVzdA==';
      final output = Echotils.base64ToArrayBuffer(input);
      expect(
        output,
        equals(
          Uint8List.fromList([
            98,
            97,
            115,
            101,
            54,
            52,
            32,
            105,
            115,
            32,
            97,
            32,
            116,
            101,
            115,
            116,
          ]),
        ),
      );
    });
  });

  group('stringToArrayBuffer method tests', () {
    test('must return a buffer from a provided string', () {
      const value = 'Hello, world!';
      final result = Echotils.stringToArrayBuffer(value);
      expect(
        result,
        Uint8List.fromList(
          [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33],
        ),
      );
    });
  });

  group('arrayBufferToBase64 method tests', () {
    test('must return base64 from array buffer', () {
      final buffer = Uint8List.fromList([104, 101, 108, 108, 111]);
      final result = Echotils.arrayBufferToBase64(buffer);

      expect(result, equals('aGVsbG8='));
    });
  });

  group('btoa Method Test', () {
    test('Must return correct result based on input', () {
      const input = '12345';
      final result = Echotils.btoa(input);
      expect(result, 'MTIzNDU=');
    });

    test('Must return valid output when input is long text', () {
      const input =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. Sed sit amet ipsum mauris. Maecenas congue ligula ac quam viverra nec consectetur ante hendrerit.';
      final result = Echotils.btoa(input);
      const expected =
          'TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4gRG9uZWMgYSBkaWFtIGxlY3R1cy4gU2VkIHNpdCBhbWV0IGlwc3VtIG1hdXJpcy4gTWFlY2VuYXMgY29uZ3VlIGxpZ3VsYSBhYyBxdWFtIHZpdmVycmEgbmVjIGNvbnNlY3RldHVyIGFudGUgaGVuZHJlcml0Lg==';
      expect(result, expected);
    });
  });
}
