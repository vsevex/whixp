import 'package:echo/src/echo.dart';
import 'package:echo/src/utils.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('getNamespace method Test', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;

    /// [Handler] with options initialization.
    Handler? handlerWOptions;
    setUp(
      () {
        handler = Handler(namespace: 'http://example.com');

        const options = {'ignoreNamespaceFragment': true};

        /// Handler with options decleration.
        handlerWOptions = Handler(options: options);

        /// Create element with the given name.
        element = Utils.xmlElement('element');
      },
    );

    test(
      'Must return valid namespace with namespace and `ignoreNamespaceFragment` set to false',
      () {
        element!.setAttribute('xmlns', 'http://blin.com#fragment');
        final namespace = handler!.getNamespace(element!);
        expect(namespace, equals('http://blin.com#fragment'));
      },
    );

    test(
        'Must return valid namespace with a namespace and `ignoreNamespaceFragment` set to true',
        () {
      element!.setAttribute('xmlns', 'http://example.com#fragment');
      final namespace = handlerWOptions!.getNamespace(element!);
      expect(namespace, equals('http://example.com'));
    });
  });

  group('namespaceMatch Method Test', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;
    setUp(
      () {
        handler = Handler(namespace: 'http://example.com');

        /// Create element with the given name.
        element = Utils.xmlElement('element');
      },
    );

    test('Must return true with no namespace given', () {
      /// Handler without namespace
      final handler = Handler();
      final result = handler.namespaceMatch(element!);
      expect(result, isTrue);
    });

    test('Must return true with a matching namespace', () {
      element!.setAttribute('xmlns', 'http://example.com');
      final result = handler!.namespaceMatch(element!);
      expect(result, isTrue);
    });

    test('Must return false with a non-matching namespace', () {
      element!.setAttribute('xmlns', 'http://blin.com');
      final result = handler!.namespaceMatch(element!);
      expect(result, isFalse);
    });

    test(
      'Must return true with a matching namespace and among child elements',
      () {
        final firstChild = Utils.xmlElement('hehe');
        firstChild!.setAttribute('xmlns', 'http://blin.com');
        final secondChild = Utils.xmlElement('hehehe');
        secondChild!.setAttribute('xmlns', 'http://example.com');
        element!.children.addAll([firstChild, secondChild]);
        final result = handler!.namespaceMatch(element!);
        expect(result, isTrue);
      },
    );

    test(
      'Must return false with a no namespace and among child elements',
      () {
        final firstChild = Utils.xmlElement('hehe');
        final secondChild = Utils.xmlElement('hehehe');
        element!.children.addAll([firstChild!, secondChild!]);
        final result = handler!.namespaceMatch(element!);
        expect(result, isFalse);
      },
    );
  });

  group('isMatch Method Test', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;
    setUp(
      () {
        handler = Handler(
          namespace: 'http://example.com',
          name: 'element',
          type: 'type',
          id: 'id',
          from: 'from',
        );

        /// Create element with the given name.
        element = Utils.xmlElement('element');
      },
    );
    test('Must return true with all parameters matching', () {
      element!
        ..setAttribute('xmlns', 'http://example.com')
        ..setAttribute('type', 'type')
        ..setAttribute('id', 'id')
        ..setAttribute('from', 'from');

      final result = handler!.isMatch(element!);
      expect(result, isTrue);
    });

    test('Must return true with missing optional params', () {
      final handler = Handler(namespace: 'http://example.com');
      element!.setAttribute('xmlns', 'http://example.com');
      final result = handler.isMatch(element!);
      expect(result, isTrue);
    });
    test('Must return false with mismatched namespace', () {
      final handler = Handler(namespace: 'http://example.com');
      element!.setAttribute('xmlns', 'http://blin.com');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test('Must return false wiht mismatched element name', () {
      final handler = Handler(name: 'element');
      final element = Utils.xmlElement('artyom');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test('Must return false with mismatched element type', () {
      final handler = Handler(type: 'type');
      final element = Utils.xmlElement('alyosha');
      element!.setAttribute('type', 'human');
      final result = handler.isMatch(element);
      expect(result, isFalse);
    });

    test('Must return false with mismatched id', () {
      final handler = Handler(id: 'id');
      element!.setAttribute('id', 'lol');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test(
      'Must return true with `matchBareFromJid` option enabled, and matching `from` attribute',
      () {
        const options = {'matchBareFromJid': true};
        final handler = Handler(from: 'user@example.com', options: options);
        element!.setAttribute('from', 'user@example.com/resource');
        final result = handler.isMatch(element!);
        expect(result, isTrue);
      },
    );
  });

  group('run() Method Test', () {
    test(
      'Must return true with a callback that returns a truthy value',
      () {
        final handler = Handler(handler: ([xml.XmlElement? element]) => true);
        final element = Utils.xmlElement('element');
        final shouldRemainActive = handler.run(element!);
        expect(shouldRemainActive, isTrue);
      },
    );

    test('Must return false with a callback that returns a falsy value', () {
      final handler = Handler(handler: ([xml.XmlElement? element]) => false);
      final element = Utils.xmlElement('element');
      final shouldRemainActive = handler.run(element!);
      expect(shouldRemainActive, isFalse);
    });

    test('Must throw an exception', () {
      final handler = Handler(
        handler: ([xml.XmlElement? element]) => throw Exception('Blin'),
      );
      final element = Utils.xmlElement('element');
      try {
        handler.run(element!);
      } catch (error) {
        rethrow;
      }
    });

    test('Must return true with a callback that modifies the element', () {
      final handler = Handler(
        handler: ([xml.XmlElement? element]) {
          element!.setAttribute('modified', 'true');
          return true;
        },
      );
      final element = Utils.xmlElement('element');
      final shouldRemainActive = handler.run(element!);
      expect(shouldRemainActive, isTrue);
      expect(element.getAttribute('modified'), equals('true'));
    });
  });
}
