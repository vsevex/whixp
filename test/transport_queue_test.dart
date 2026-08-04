import 'dart:async' as async;

import 'package:test/test.dart';
import 'package:whixp/src/performance/sequential_queue.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';

void main() {
  group('transport queue', () {
    test(
      'waits for async pre-send work before processing the next packet',
      () async {
        final controller = async.StreamController<Packet>();
        final releaseMessage = async.Completer<void>();
        final processed = <String>[];

        final queue = SequentialQueue<Packet>(
          stream: controller.stream,
          process: (packet) async {
            processed.add('${packet.name}:start');
            if (processed.length == 1) {
              await releaseMessage.future;
            }
            processed.add('${packet.name}:end');
          },
        );

        controller
          ..add(Message(body: 'hello'))
          ..add(Message(body: 'world'));

        await async.Future<void>.delayed(const Duration(milliseconds: 10));

        expect(processed, equals(['message:start']));

        releaseMessage.complete();
        await controller.close();
        await queue.drained;

        expect(
          processed,
          equals([
            'message:start',
            'message:end',
            'message:start',
            'message:end',
          ]),
        );
      },
    );

    test('keeps processing after a packet fails', () async {
      final controller = async.StreamController<Packet>();
      final processed = <String>[];
      final errors = <Object>[];

      final queue = SequentialQueue<Packet>(
        stream: controller.stream,
        process: (packet) async {
          await async.Future<void>.delayed(Duration.zero);
          final body = (packet as Message).body;
          if (body == 'boom') throw StateError('boom');
          processed.add(body!);
        },
        onError: (error, _) => errors.add(error),
      );

      controller
        ..add(Message(body: 'first'))
        ..add(Message(body: 'boom'))
        ..add(Message(body: 'second'));

      await controller.close();
      await queue.drained;

      expect(processed, equals(['first', 'second']));
      expect(errors, hasLength(1));
      expect(errors.single, isStateError);
    });

    test('stops processing packets once cancelled', () async {
      final controller = async.StreamController<Packet>();
      final release = async.Completer<void>();
      final processed = <String>[];

      final queue = SequentialQueue<Packet>(
        stream: controller.stream,
        process: (packet) async {
          processed.add((packet as Message).body!);
          await release.future;
        },
      );

      controller
        ..add(Message(body: 'first'))
        ..add(Message(body: 'second'));

      await async.Future<void>.delayed(const Duration(milliseconds: 10));
      await queue.cancel();
      release.complete();
      await queue.drained;

      /// `second` was already delivered to the listener when cancel() landed,
      /// but had not started processing, so it must be dropped rather than sent
      /// on a connection that is being torn down.
      expect(processed, equals(['first']));

      await controller.close();
    });
  });
}
