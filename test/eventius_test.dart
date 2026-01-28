import 'package:test/test.dart';

import 'package:whixp/src/handler/eventius.dart';

void main() {
  late Eventius eventius;

  setUp(() => eventius = Eventius());

  group('Eventius class test cases', () {
    test('event happening must work properly', () {
      final happened = <bool?>[];

      void testEvent(bool? data) => happened.add(data);

      eventius.on<bool>('test', testEvent);
      eventius.emit<bool>('test', true);
      eventius.emit<bool>('test', true);

      expect(happened.length, equals(2));
      expect(happened, equals([true, true]));
    });

    test('must create event handler properly', () {
      late String? substring;
      void handler(String? data) {
        substring = data?.substring(1);
        return;
      }

      eventius.on<String>('test', handler);
      eventius.emit<String>('test');
      expect(substring, isNull);
      eventius.emit<String>('test', 'blya');
      expect(substring, equals('lya'));
    });

    test('adding multiple listeners should be allowed', () async {
      final happened = <bool>[];

      void testEvent(bool? data) => happened.add(true);

      void testEventSecond(bool? data) => happened.add(false);

      eventius.on<bool>('test', testEvent);
      eventius.on<bool>('test', testEventSecond);

      await eventius.emit<bool>('test');
      await eventius.emit<bool>('test');

      expect(happened.length, equals(4));
      expect(happened, equals([true, false, true, false]));
    });

    test('must properly handle future test cases', () {
      final handlers = <String>[];

      eventius.on<String>('testAsync', (data) {
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

      eventius.on<String>('testSync', (data) {
        if (data != null) {
          handlers.add('handled non-future: $data');
        } else {
          handlers.add('handled non-future');
        }
      });

      eventius.emit<String>('testAsync', 'hert');
      expect(handlers, isEmpty);
      eventius.emit<String>('testSync', 'hert');
      expect(handlers.length, equals(1));
      expect(handlers, equals(['handled non-future: hert']));
      eventius.emit<String>('testAsync', 'cart');
      Future.delayed(
        const Duration(milliseconds: 1000),
        () {
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
      final happened = <bool?>[];

      void testEvent(bool? data) => happened.add(data);
      final removeListener = eventius.on<bool>('test', testEvent);

      eventius.emit<bool>('test', true);
      removeListener.call();
      eventius.emit<bool>('test', true);
      eventius.on<bool>('test', testEvent);
      eventius.emit<bool>('test', true);

      expect(happened.length, equals(2));
      expect(happened, equals([true, true]));
    });

    test('try throwing Exception while calling the handler', () {
      void testEvent(String? data) {
        if (data != null) return;
        throw Exception('some error');
      }

      eventius.on('test', testEvent);

      expect(
        () => eventius.emit<String>('test'),
        throwsA(const TypeMatcher<Exception>()),
      );
      expect(() => eventius.emit<String>('test', 'cart'), returnsNormally);
    });

    test(
        'must call callback once, then dispose the given callback and do not run on call',
        () {
      final happened = <bool?>[];

      void testEvent(bool? data) => happened.add(data);
      eventius.once<bool>('test', testEvent);

      eventius.emit<bool>('test', true);
      eventius.emit<bool>('test', true);

      expect(happened.length, equals(1));
      expect(happened, equals([true]));
    });
  });
}
