import 'dart:async' as async;

import 'package:test/test.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/transport.dart';

void main() {
  group('transport queue', () {
    test(
      'waits for async pre-send work before processing the next packet',
      () async {
        final controller = async.StreamController<Packet>();
        final releaseMessage = async.Completer<void>();
        final processed = <String>[];

        final processing = processTransportQueueSequentially<Packet>(
          stream: controller.stream,
          processData: (packet) async {
            processed.add('${packet.name}:start');
            if (packet is Message) {
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
        await processing;

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
  });
}
