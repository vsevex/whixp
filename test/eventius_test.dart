import 'package:echox/src/handler/eventius.dart';

import 'package:events_emitter/events_emitter.dart';

import 'package:test/test.dart';

void main() {
  late Eventius eventius;

  setUp(() => eventius = Eventius(EventEmitter()));

  group('Eventius class test cases', () {
    test('event happening must work properly', () {
      final happened = <bool>[];

      void testEvent(bool? data) => happened.add(data!);
      final listener = EventListener<bool?>('test', testEvent);

      eventius.addEvent(listener);
      eventius.emit<bool>('test', true);
      eventius.emit<bool>('test', true);

      expect(happened.length, equals(2));
      expect(happened, equals([true, true]));
    });

    test('must create event listener properly', () {
      late String? substring;
      final listener = eventius.createListener<String>(
        'test',
        (data) => substring = data?.substring(1),
      );

      eventius.addEvent(listener);
      eventius.emit<String>('test');
      expect(substring, isNull);
      eventius.emit<String>('test', 'blya');
      expect(substring, equals('lya'));
    });

    test('adding multiple listeners should be allowed', () async {
      final happened = <bool>[];

      void testEvent(_) => happened.add(true);
      void testEventSecond(_) => happened.add(false);

      final listener = EventListener<bool?>('test', testEvent);
      final listener2 = EventListener<bool?>('test', testEventSecond);

      eventius
        ..addEvent(listener)
        ..addEvent(listener2);

      eventius.emit<bool>('test');
      eventius.emit<bool>('test');

      expect(happened.length, equals(4));
      expect(happened, equals([true, false, true, false]));
    });

    test('must properly handle future test cases', () {
      final handlers = <String>[];
      final listenerAsync =
          eventius.createListener<String>('testAsync', (data) async {
        if (data != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            handlers.add('handled future: $data');
          });
        } else {
          Future.delayed(const Duration(milliseconds: 1500), () {
            handlers.add('handled future');
          });
        }
      });

      final listenerSync = eventius.createListener<String>('testSync', (data) {
        if (data != null) {
          handlers.add('handled non-future: $data');
        } else {
          handlers.add('handled non-future');
        }
      });

      eventius.addEvent(listenerAsync);
      eventius.addEvent(listenerSync);
      eventius.emit('testAsync', 'hert');
      expect(handlers, isEmpty);
      eventius.emit('testSync', 'hert');
      expect(handlers.length, equals(1));
      expect(handlers, equals(['handled non-future: hert']));
      eventius.emit('testAsync', 'cart');
      Future.delayed(
        const Duration(milliseconds: 1000),
        () async {
          expect(
            handlers,
            equals([
              'handled non-future: hert',
              'handled future: hert',
              'handled future: cart',
            ]),
          );
          expect(handlers.length, equals(3));
        },
      );
    });

    test('test adding, removing, then adding an event handler', () {
      final happened = <bool>[];

      void testEvent(bool? data) => happened.add(data!);
      final listener = EventListener<bool?>('test', testEvent);

      eventius.addEvent(listener);
      eventius.emit<bool>('test', true);
      eventius.removeEventHandler<bool>(listener: listener);
      eventius.emit<bool>('test', true);
      eventius.addEvent(listener);
      eventius.emit<bool>('test', true);

      expect(happened.length, equals(2));
      expect(happened, equals([true, true]));
    });

    test('try throwing Exception while calling the handler', () {
      void testEvent(data) {
        if (data != null) return;
        throw Exception('some error');
      }

      final listener = eventius.createListener('test', testEvent);

      eventius.addEvent(listener);
      expect(
        () => eventius.emit('test', null),
        throwsA(const TypeMatcher<Exception>()),
      );
      expect(() => eventius.emit('test', 'cart'), returnsNormally);
    });

    test(
        'must call callback once, then dispose the given callback and do not run on call',
        () {
      final happened = <bool>[];

      void testEvent(bool? data) => happened.add(data!);
      final listener = EventListener<bool?>('test', testEvent, once: true);

      eventius.addEvent(listener);
      eventius.emit('test', true);
      eventius.emit('test', true);

      expect(happened.length, equals(1));
      expect(happened, equals([true]));
    });
  });
}
