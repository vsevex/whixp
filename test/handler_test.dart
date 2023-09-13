import 'package:echo/echo.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  group('getNamespace method tests', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;

    /// [Handler] with options initialization.
    Handler? handlerWOptions;
    setUpAll(
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
      'must return valid namespace with namespace and `ignoreNamespaceFragment` set to false',
      () {
        element!.setAttribute('xmlns', 'http://blin.com#fragment');
        final namespace = handler!.getNamespace(element!);
        expect(namespace, equals('http://blin.com#fragment'));
      },
    );

    test(
        'returns valid namespace with a namespace and `ignoreNamespaceFragment` set to true',
        () {
      element!.setAttribute('xmlns', 'http://example.com#fragment');
      final namespace = handlerWOptions!.getNamespace(element!);
      expect(namespace, equals('http://example.com'));
    });
  });

  group('namespaceMatch method tests', () {
    /// Global element initialization.
    late xml.XmlElement element;
    late Handler handler;
    setUpAll(
      () {
        handler = Handler(
          (element) async {
            return false;
          },
          namespace: 'http://example.com',
        );
      },
    );

    setUp(() {
      /// Create element with the given name.
      element = Echotils.xmlElement('element');
    });

    test('must return true with no namespace given', () {
      /// Handler without namespace
      final handler = Handler((element) async {
        return false;
      });
      final result = handler.namespaceMatch(element);
      expect(result, isTrue);
    });

    test('must return true with a matching namespace', () {
      element.setAttribute('xmlns', 'http://example.com');
      final result = handler.namespaceMatch(element);
      expect(result, isTrue);
    });

    test('returns false with a non-matching namespace', () {
      element.setAttribute('xmlns', 'http://blin.com');
      final result = handler.namespaceMatch(element);
      expect(result, isFalse);
    });

    test(
      'must return true with a matching namespace and among child elements',
      () {
        final firstChild = Echotils.xmlElement('hehe');
        firstChild.setAttribute('xmlns', 'http://blin.com');
        final secondChild = Echotils.xmlElement('hehehe');
        secondChild.setAttribute('xmlns', 'http://example.com');
        element.children.addAll([firstChild, secondChild]);
        final result = handler.namespaceMatch(element);
        expect(result, isTrue);
      },
    );

    test(
      'must return false without namespace and among child elements',
      () {
        final firstChild = Echotils.xmlElement('hehe');
        final secondChild = Echotils.xmlElement('hehehe');
        element.children.addAll([firstChild, secondChild]);
        final result = handler.namespaceMatch(element);
        expect(result, isFalse);
      },
    );
  });

  group('isMatch method tests', () {
    /// Global element initialization.
    xml.XmlElement? element;
    Handler? handler;
    setUpAll(
      () {
        handler = Handler(
          (element) async {
            return false;
          },
          namespace: 'http://example.com',
          name: 'element',
          type: 'type',
          id: 'id',
          from: 'from',
        );

        /// Create element with the given name.
        element = Echotils.xmlElement('element');
      },
    );
    test('must return true with all parameters matching', () {
      element!
        ..setAttribute('xmlns', 'http://example.com')
        ..setAttribute('type', 'type')
        ..setAttribute('id', 'id')
        ..setAttribute('from', 'from');

      final result = handler!.isMatch(element!);
      expect(result, isTrue);
    });

    test('must return true with missing optional params', () {
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
    test('must return false with mismatched namespace', () {
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

    test('must return false wiht mismatched element name', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        name: 'element',
      );
      final element = Echotils.xmlElement('artyom');
      final result = handler.isMatch(element);
      expect(result, isFalse);
    });

    test('must return false with mismatched element type', () {
      final handler = Handler(
        (element) async {
          return false;
        },
        type: 'type',
      );
      final element = Echotils.xmlElement('alyosha');
      element.setAttribute('type', 'human');
      final result = handler.isMatch(element);
      expect(result, isFalse);
    });

    test('must return false with mismatched id', () {
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
      'must return true with `matchBareFromJid` option enabled, and matching `from` attribute',
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

  group('run method tests', () {
    test(
      'returns true with a callback that returns a truthy value',
      () async {
        final handler = Handler((element) async => true);
        final element = Echotils.xmlElement('element');
        final shouldRemainActive = await handler.run(element);
        expect(shouldRemainActive, isTrue);
      },
    );

    test('returns false with a callback that returns a falsy value', () async {
      final handler = Handler((element) async => false);
      final element = Echotils.xmlElement('element');
      final shouldRemainActive = await handler.run(element);
      expect(shouldRemainActive, isFalse);
    });

    test('must throw an exception', () async {
      final handler = Handler((element) => true);
      final element = Echotils.xmlElement('element');
      try {
        await handler.run(element);
      } catch (error) {
        rethrow;
      }
    });

    test('must return true with a callback that modifies the element',
        () async {
      final handler = Handler(
        (element) async {
          element.setAttribute('modified', 'true');
          return true;
        },
      );
      final element = Echotils.xmlElement('element');
      final shouldRemainActive = await handler.run(element);
      expect(shouldRemainActive, isTrue);
      expect(element.getAttribute('modified'), equals('true'));
    });
  });
}
