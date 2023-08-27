import 'dart:async';

import 'package:event/event.dart';

import 'package:test/test.dart';

void main() {
  late Eventius<String> eventius;

  setUp(() {
    eventius = Eventius<String>(historyLimit: 0);
  });

  group('listener related actions', () {
    test('adds and notify listeners', () {
      final listenerCalled = <String?>[];

      final listener =
          eventius.addListener((payload) => listenerCalled.add(payload));

      eventius.fire('test_payload');

      expect(listenerCalled, equals(['test_payload']));
      listener();
    });

    test('adds and notify filtered listeners', () {
      final filteredListenerCalled = <String?>[];

      final listener = eventius.addFilteredListener(
        (payload) {
          filteredListenerCalled.add(payload);
        },
        filter: (payload) => payload.contains('test'),
      );

      eventius.fire('test_payload');
      eventius.fire('another_payload');

      expect(filteredListenerCalled, equals(['test_payload']));
      listener();
    });

    test('remove a listener', () {
      final listenerCalled = <String?>[];

      final listener =
          eventius.addListener((payload) => listenerCalled.add(payload));

      eventius.fire('test_payload');
      expect(listenerCalled, equals(['test_payload']));
      listener();

      eventius.fire('another_payload');

      /// should not change due listener is removed
      expect(
        listenerCalled,
        equals(['test_payload']),
      );
    });
  });

  group('once method tests', () {
    test('onceListener should be invoked only once', () async {
      int onceListenerInvocationCount = 0;

      int onceListener(String? payload) => onceListenerInvocationCount++;

      eventius.once(onceListener);
      await eventius.fire('blya');

      expect(onceListenerInvocationCount, equals(1));

      eventius.fire('someInvocation');

      expect(onceListenerInvocationCount, equals(1));
    });

    test('onceListeners should be invoked before regular listeners', () {
      final events = <String?>[];

      void onceListener(String? payload) {
        events.add('OnceListener: $payload');
      }

      void regularListener(String? payload) {
        events.add('RegularListener: $payload');
      }

      eventius
        ..once(onceListener)
        ..addListener(regularListener);

      eventius.fire('blya');
      eventius.fire('hert');

      expect(
        events,
        equals([
          'OnceListener: blya',
          'RegularListener: blya',
          'RegularListener: hert',
        ]),
      );
    });
  });

  group('use history on listener scope', () {
    test('use history when adding a listener', () {
      final listenerCalled = <String?>[];

      eventius.fire('test_payload1');
      eventius.fire('test_payload2');

      final listener = eventius.addListener(
        (payload) {
          listenerCalled.add(payload);
        },
        useHistory: true,
      );

      expect(listenerCalled, equals(['test_payload1', 'test_payload2']));

      listener();
    });

    test('not using history when adding a listener', () {
      final listenerCalled = <String?>[];

      eventius.fire('test_payload1');
      eventius.fire('test_payload2');

      final listener =
          eventius.addListener((payload) => listenerCalled.add(payload));

      expect(listenerCalled, isEmpty);

      listener();
    });
  });

  group('use history on fire method scope', () {
    test('adding payloads to history when using useHistory', () async {
      final completer = Completer<void>();

      final listener = eventius.addListener(
        (payload) {
          if (payload == 'test_payload') {
            completer.complete();
          }
        },
        useHistory: true,
      );

      await eventius.fire('test_payload');
      await completer.future;
      expect(eventius.historySize, equals(1));

      listener();
    });

    test('not adding payloads to history when not using useHistory', () async {
      final completer = Completer<void>();

      final listener = eventius.addListener(
        (payload) {
          if (payload == 'test_payload') {
            completer.complete();
          }
        },
      );

      await eventius.fire('test_payload', useHistory: false);
      await completer.future;

      expect(eventius.historySize, equals(0));

      listener();
    });
  });

  group('linkTo method tests', () {
    test('linkTo should propagate events to linked Eventius', () {
      final eventius1 = Eventius<int?>();

      int converter(String payload) => payload.length;

      eventius.linkTo(eventius1, converter);

      int? receivedValue;

      eventius1.addFilteredListener(
        (payload) => receivedValue = payload,
        filter: (value) => value != null,
      );

      eventius.fire('blya');
      expect(receivedValue, equals(4));
    });

    test('linkTo should delay notification', () async {
      final eventius1 = Eventius<int>();

      int converter(String value) => value.length;

      eventius.linkTo(eventius1, converter);

      int? receivedValue;

      eventius1.addListener((payload) => receivedValue = payload);

      eventius.fire('hert');

      await Future.delayed(const Duration(milliseconds: 150));

      expect(receivedValue, equals(4));
    });
  });

  group('listenTo method tests', () {
    test('listenTo should forward clalbacks to the current instance', () {
      final eventius1 = Eventius<String>();

      final listener = eventius.listenTo(eventius1);
      String? receivedValue;

      eventius.addListener((payload) => receivedValue = payload);
      eventius1.fire('blya');

      expect(receivedValue, equals('blya'));

      listener();

      eventius1.fire('hert');

      expect(receivedValue, equals('blya'));
    });

    test('listenTo should delay forwarded payloads', () async {
      final eventius1 = Eventius<String>();

      final listener = eventius.listenTo(
        eventius1,
        delay: const Duration(milliseconds: 300),
      );

      String? receivedValue;

      eventius.addListener((payload) => receivedValue = payload);

      eventius1.fire('blya');

      expect(receivedValue, isNull);

      await Future.delayed(const Duration(milliseconds: 350));

      expect(receivedValue, equals('blya'));

      listener();
    });
  });

  group('clear methods', () {
    test('clearing all listeners', () {
      final listenerCalled = <String?>[];

      eventius.addListener((payload) => listenerCalled.add(payload));

      eventius.clear();

      eventius.fire('test_payload');

      expect(listenerCalled, isEmpty);
    });

    test('clearing listeners with a filter', () {
      final listenerCalled = <String?>[];

      eventius.addListener((payload) => listenerCalled.add(payload));

      void eventListener(String? payload) => listenerCalled.add(payload);

      eventius.addListener(eventListener);

      eventius.clear((listener) => listener == eventListener);

      eventius.fire('test_payload');

      expect(listenerCalled, equals(['test_payload']));
    });

    test('clearing history', () {
      eventius.fire('test_payload1');
      eventius.fire('test_payload2');

      eventius.clearHistory();

      expect(eventius.historySize, equals(0));
    });
  });
}
