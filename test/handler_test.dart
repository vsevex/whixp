import 'package:echo/src/echo.dart';
import 'package:echo/src/utils.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('getNamespace Method Test', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;

    /// [Handler] with options initialization.
    Handler? handlerWOptions;
    setUp(
      () {
        handler = Handler(
          (element) async {
            return false;
          },
          namespace: 'http://example.com',
        );

        const options = {'ignoreNamespaceFragment': true};

        /// Handler with options decleration.
        handlerWOptions = Handler(
          (element) async {
            return false;
          },
          options: options,
        );

        /// Create element with the given name.
        element = Echotils.xmlElement('element');
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
        handler = Handler(
          (element) async {
            return false;
          },
          namespace: 'http://example.com',
        );

        /// Create element with the given name.
        element = Echotils.xmlElement('element');
      },
    );

    test('Must return true with no namespace given', () {
      /// Handler without namespace
      final handler = Handler((element) async {
        return false;
      });
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
        final firstChild = Echotils.xmlElement('hehe');
        firstChild!.setAttribute('xmlns', 'http://blin.com');
        final secondChild = Echotils.xmlElement('hehehe');
        secondChild!.setAttribute('xmlns', 'http://example.com');
        element!.children.addAll([firstChild, secondChild]);
        final result = handler!.namespaceMatch(element!);
        expect(result, isTrue);
      },
    );

    test(
      'Must return false with a no namespace and among child elements',
      () {
        final firstChild = Echotils.xmlElement('hehe');
        final secondChild = Echotils.xmlElement('hehehe');
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
          (element) async {
            return false;
          },
          namespace: 'http://example.com',
          stanzaName: 'element',
          type: 'type',
          id: 'id',
          from: 'from',
        );

        /// Create element with the given name.
        element = Echotils.xmlElement('element');
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
      final handler = Handler(
        (element) async {
          return false;
        },
        namespace: 'http://example.com',
      );
      element!.setAttribute('xmlns', 'http://example.com');
      final result = handler.isMatch(element!);
      expect(result, isTrue);
    });
    test('Must return false with mismatched namespace', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        namespace: 'http://example.com',
      );
      element!.setAttribute('xmlns', 'http://blin.com');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test('Must return false wiht mismatched element name', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        stanzaName: 'element',
      );
      final element = Echotils.xmlElement('artyom');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test('Must return false with mismatched element type', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        type: 'type',
      );
      final element = Echotils.xmlElement('alyosha');
      element!.setAttribute('type', 'human');
      final result = handler.isMatch(element);
      expect(result, isFalse);
    });

    test('Must return false with mismatched id', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        id: 'id',
      );
      element!.setAttribute('id', 'lol');
      final result = handler.isMatch(element!);
      expect(result, isFalse);
    });

    test(
      'Must return true with `matchBareFromJid` option enabled, and matching `from` attribute',
      () {
        const options = {'matchBareFromJid': true};
        final handler = Handler(
          (element) async {
            return false;
          },
          from: 'user@example.com',
          options: options,
        );
        element!.setAttribute('from', 'user@example.com/resource');
        final result = handler.isMatch(element!);
        expect(result, isTrue);
      },
    );
  });

  group('run() Method Test', () {
    test(
      'Must return true with a callback that returns a truthy value',
      () async {
        final handler = Handler((element) async => true);
        final element = Echotils.xmlElement('element');
        final shouldRemainActive = await handler.run(element!);
        expect(shouldRemainActive, isTrue);
      },
    );

    test('Must return false with a callback that returns a falsy value',
        () async {
      final handler = Handler((element) async => false);
      final element = Echotils.xmlElement('element');
      final shouldRemainActive = await handler.run(element!);
      expect(shouldRemainActive, isFalse);
    });

    test('Must throw an exception', () async {
      final handler = Handler((element) => true);
      final element = Echotils.xmlElement('element');
      try {
        await handler.run(element!);
      } catch (error) {
        rethrow;
      }
    });

    test('Must return true with a callback that modifies the element',
        () async {
      final handler = Handler(
        (element) async {
          element.setAttribute('modified', 'true');
          return true;
        },
      );
      final element = Echotils.xmlElement('element');
      final shouldRemainActive = await handler.run(element!);
      expect(shouldRemainActive, isTrue);
      expect(element.getAttribute('modified'), equals('true'));
    });
  });
}
